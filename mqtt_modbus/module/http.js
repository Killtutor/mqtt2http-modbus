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
    const toSend = `http://tomcat:8080/httpds?&${parametro}=${encodeURI(
      message ? message.toString() : ""
    )}&__device=${sede}&__time=${dayjs()
      .subtract(4, "hours")
      .format("YYYYMMDDHHMMSS")}`;
    console.log("🚀 ~ toSend:", toSend);
    return axios.get(toSend);
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
