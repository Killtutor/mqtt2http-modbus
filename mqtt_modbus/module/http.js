"use strict";
const config = require("./config.json");
const dayjs = require("dayjs");
////////// HTTP Dependencies //////////////
const express = require("express");
const bodyParser = require("body-parser");

////////// MQTT Dependencies //////////////
const mqtt = require("mqtt");
const { default: axios } = require("axios");

const initialize = async () => {
  ////////// MQTT Functions //////////////
  // Inicialize the mqtt client
  const client = mqtt.connect(
    `mqtt://${process.env.MQTT_HOST || config.mqttHost}:${
      process.env.MQTT_PORT || config.mqttPort
    }`,
    {
      password: process.env.MQTT_PASS || config.mqttPass,
      username: process.env.MQTT_USER || config.mqttUser
    }
  );
  // When connected Let us know
  client.on("connect", function () {
    console.info("Conectado al broker. Esperando topicos para suscribirse...");
  });
  // On message we need to proccess any message
  // formato esperado: sede/parametro
  client.on("message", function (topic, message) {
    const proTopic = topic.split("/");
    const sede = proTopic.shift();
    const parametro = proTopic.shift();
    let correctedMessage = message ? message.toString() : "";
    correctedMessage = ["0", "false", "falso", "False", "Falso"].includes(
      correctedMessage
    )
      ? "0"
      : correctedMessage;
    correctedMessage = ["1", "true", "verdadero", "True", "Verdadero"].includes(
      correctedMessage
    )
      ? "1"
      : correctedMessage;
    try {
      const jsonMessage = JSON.parse(correctedMessage);
      if (typeof jsonMessage !== "object") {
        throw new Error("El mensaje no es un objeto valido");
      }
      for (const key in jsonMessage) {
        const toSend = `http://tomcat:8080/httpds?&${key}=${encodeURI(
          jsonMessage[key]
        )}&__device=${sede}&__time=${dayjs()
          .subtract(4, "hours")
          .format("YYYYMMDDHHMMSS")}`;
        axios.get(toSend);
      }
    } catch (error) {
      const toSend = `http://tomcat:8080/httpds?&${parametro}=${encodeURI(
        correctedMessage
      )}&__device=${sede}&__time=${dayjs()
        .subtract(4, "hours")
        .format("YYYYMMDDHHMMSS")}`;
      return axios.get(toSend);
    }
  });

  ////////// HTTP Functions //////////////
  var app = express();
  app.use(bodyParser.urlencoded({ extended: false }));
  app.use(bodyParser.json());

  app.listen(config.httpRealTime.port, () => {
    console.info(
      `HTTP Control server escuchando al puerto ${config.httpRealTime.port}`
    );
  });

  for (const device of config.httpRealTime.devices) {
    client.subscribe(`${device.nombre}/#`);
  }
};
initialize();
