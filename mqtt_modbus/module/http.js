"use strict";
const config = require("./config.json");
const dayjs = require("dayjs");
////////// HTTP Dependencies //////////////
const express = require("express");
const bodyParser = require("body-parser");

////////// MQTT Dependencies //////////////
const mqtt = require("mqtt");
const { default: axios } = require("axios");

// Message counter
let processedMessages = 0;
let failedRequests = 0;

// Create axios instance with defaults
const httpClient = axios.create({
  timeout: 5000, // 5 second timeout
  maxRedirects: 3
});

// Simple exponential backoff for retries
const backoff = (attempt) => Math.min(Math.pow(2, attempt) * 100, 10000);

// Function to send HTTP request with retry logic
const sendHttpRequest = async (url, retries = 3, attempt = 0) => {
  try {
    return await httpClient.get(url);
  } catch (error) {
    if (attempt < retries) {
      const delay = backoff(attempt);
      console.info(
        `Retrying request to ${url} after ${delay}ms (attempt ${
          attempt + 1
        }/${retries})`
      );
      await new Promise((resolve) => setTimeout(resolve, delay));
      return sendHttpRequest(url, retries, attempt + 1);
    }

    failedRequests++;
    console.error(`Failed to send HTTP request after ${retries} attempts:`, {
      url,
      error: error.message,
      statusCode: error.response?.status,
      data: error.response?.data
    });
    throw error;
  }
};

const initialize = async () => {
  ////////// MQTT Functions //////////////
  // Inicialize the mqtt client with reconnection options
  const client = mqtt.connect(
    `mqtt://${process.env.MQTT_HOST || config.mqttHost}:${
      process.env.MQTT_PORT || config.mqttPort
    }`,
    {
      password: process.env.MQTT_PASS || config.mqttPass,
      username: process.env.MQTT_USER || config.mqttUser,
      reconnectPeriod: 5000, // Reconnect every 5 seconds if connection is lost
      connectTimeout: 10000, // 10 seconds connection timeout
      clean: true, // Clean session
      queueQoSZero: false // Don't queue offline QoS 0 messages
    }
  );

  // When connected Let us know
  client.on("connect", function () {
    console.info("Conectado al broker. Esperando topicos para suscribirse...");

    // Subscribe to stats request topics
    client.subscribe("http_module/stats/request", { qos: 1 });
    client.subscribe("http_module/stats/reset", { qos: 1 });

    // Subscribe to all configured devices
    for (const device of config.httpRealTime.devices) {
      client.subscribe(`${device.nombre}/#`, { qos: 1 });
      console.info(`Subscribed to ${device.nombre}/#`);
    }
  });

  // Handle MQTT errors
  client.on("error", function (error) {
    console.error("MQTT client error:", error.message);
  });

  client.on("offline", function () {
    console.warn("MQTT client went offline, attempting to reconnect...");
  });

  client.on("reconnect", function () {
    console.info("MQTT client attempting to reconnect...");
  });

  // On message we need to proccess any message
  // formato esperado: sede/parametro
  client.on("message", async function (topic, message) {
    try {
      // Check if this is a stats request
      if (topic === "http_module/stats/request") {
        // Publish current count to the stats response topic
        client.publish(
          "http_module/stats/response",
          JSON.stringify({ processedMessages, failedRequests }),
          { qos: 1 }
        );
        return;
      }

      // Check if this is a reset request
      if (topic === "http_module/stats/reset") {
        processedMessages = 0;
        failedRequests = 0;
        client.publish(
          "http_module/stats/response",
          JSON.stringify({ processedMessages, failedRequests, reset: true }),
          { qos: 1 }
        );
        return;
      }

      const proTopic = topic.split("/");
      const sede = proTopic.shift();
      const parametro = proTopic.shift();
      let correctedMessage = message ? message.toString() : "";
      correctedMessage = ["0", "false", "falso", "False", "Falso"].includes(
        correctedMessage
      )
        ? "0"
        : correctedMessage;
      correctedMessage = [
        "1",
        "true",
        "verdadero",
        "True",
        "Verdadero"
      ].includes(correctedMessage)
        ? "1"
        : correctedMessage;

      const timestamp = dayjs().subtract(4, "hours").format("YYYYMMDDHHMMSS");

      try {
        const jsonMessage = JSON.parse(correctedMessage);
        if (typeof jsonMessage !== "object") {
          throw new Error("El mensaje no es un objeto valido");
        }

        const requests = [];
        for (const key in jsonMessage) {
          const toSend = `http://tomcat:8080/httpds?${key}=${encodeURI(
            jsonMessage[key]
          )}&__device=${sede}&__time=${timestamp}`;

          requests.push(sendHttpRequest(toSend));
        }

        await Promise.allSettled(requests).then((results) => {
          const failedCount = results.filter(
            (r) => r.status === "rejected"
          ).length;
          if (failedCount > 0) {
            console.warn(`${failedCount} requests failed for topic ${topic}`);
          }
        });

        processedMessages++;
      } catch (error) {
        // Not a valid JSON, treat as single parameter
        if (!(error instanceof SyntaxError)) {
          console.error("Error processing message:", error.message);
        }

        const toSend = `http://tomcat:8080/httpds?&${parametro}=${encodeURI(
          correctedMessage
        )}&__device=${sede}&__time=${timestamp}`;

        try {
          await sendHttpRequest(toSend);
          processedMessages++;
        } catch (httpError) {
          // Error is already logged in sendHttpRequest
        }
      }
    } catch (error) {
      console.error(
        `Error processing MQTT message for topic ${topic}:`,
        error.message
      );
    }
  });

  ////////// HTTP Functions //////////////
  var app = express();
  app.use(bodyParser.urlencoded({ extended: false }));
  app.use(bodyParser.json());

  // Add basic error handling middleware
  app.use((err, req, res, next) => {
    console.error("Express error:", err.message);
    res.status(500).send("Internal Server Error");
  });

  app.listen(config.httpRealTime.port, () => {
    console.info(
      `HTTP Control server escuchando al puerto ${config.httpRealTime.port}`
    );
  });
};

// Handle uncaught exceptions
process.on("uncaughtException", (error) => {
  console.error("Uncaught exception:", error.message);
  // Keep process alive
});

// Handle unhandled promise rejections
process.on("unhandledRejection", (reason, promise) => {
  console.error("Unhandled Rejection at:", promise, "reason:", reason);
  // Keep process alive
});

initialize().catch((error) => {
  console.error("Failed to initialize server:", error.message);
});
