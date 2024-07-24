"use strict";
// MQTT import and clientConfig
const mqtt = require("mqtt");
const config = require("./config.json");
const client = mqtt.connect(`mqtt://${config.mqttHost}:${config.mqttPort}`, {
  password: config.mqttPass,
  username: config.mqttUser
});

client.on("connect", function () {
  console.info(
    "Modbus Conectado al broker. Subscrito a la configuracion inicial, para mas topicos usa el http server."
  );
});

const httpTemplates = {
  binary: {
    dataType: "BINARY",
    binary0Value: "",
    parameterName: "binario"
  },
  numeric: {
    dataType: "NUMERIC",
    binary0Value: "",
    parameterName: "numerico"
  },
  alpha: {
    dataType: "ALPHANUMERIC",
    binary0Value: "",
    parameterName: "alpha"
  },
  multi: {
    dataType: "MULTISTATE",
    binary0Value: "",
    parameterName: "multi"
  }
};

// REDIS import and Client Config
const { createClient } = require("redis");
const redis = createClient({
  url: config.redisUrl,
  name: "Modbus",
  // username: config.redisUser,
  password: config.redisPass
});
redis.on("error", (err) => console.log("Redis Client Error", err));
redis.connect();

const { writeFile } = require("fs/promises");

// Modbus retType translator
const retTypeTranslator = {
  input: "ir",
  holding: "hr",
  discrete: "dr",
  coil: "cr"
};

//formato esperado de topico: sede/RTU#/retype/addr#
//retype could be input, coil, holding, discrete
client.on("message", async function (topic, message) {
  const proTopic = topic.split("/");
  const sede = proTopic[0];
  const RTU = parseInt(proTopic[1]);
  const retype = retTypeTranslator[proTopic[2]] ?? "ir";
  const addr = proTopic[3];
  const context = message.toString("utf8");
  await redis.set(`${sede}/rtu/${RTU}/${retype}/${addr}`, String(context));
});
// Init Function, Runs once on server livespan
const initialize = async () => {
  const exportData = { dataSources: [], dataPoints: [] };
  for (const sede of config.modbusSedes) {
    initServerTCP(sede.nombre, sede.port);
    const dataSourceId = `DS_${(Math.random() * 100000).toFixed(0)}`;
    exportData.dataSources.push({
      xid: dataSourceId,
      type: "MODBUS_IP",
      alarmLevels: {
        POINT_WRITE_EXCEPTION: "URGENT",
        DATA_SOURCE_EXCEPTION: "URGENT",
        POINT_READ_EXCEPTION: "URGENT"
      },
      updatePeriodType: sede.refreshRatePeriod,
      transportType: "TCP",
      contiguousBatches: false,
      createSlaveMonitorPoints: false,
      enabled: true,
      encapsulated: false,
      host: "mqtt",
      maxReadBitCount: 2000,
      maxReadRegisterCount: 125,
      maxWriteRegisterCount: 120,
      name: sede.nombre,
      port: sede.port,
      quantize: false,
      retries: 2,
      timeout: 500,
      updatePeriods: sede.refreshRate
    });
    for (let i = 0; i < sede.rtus; i++) {
      exportData.dataPoints.push({
        xid: `DP_${(Math.random() * 100000).toFixed(0)}`,
        loggingType: "NONE",
        intervalLoggingPeriodType: "MINUTES",
        intervalLoggingType: "INSTANT",
        purgeType: "YEARS",
        pointLocator: {
          range: "COIL_STATUS",
          modbusDataType: "BINARY",
          additive: 0.0,
          bit: 0,
          charset: "ASCII",
          multiplier: 1.0,
          offset: i,
          registerCount: 0,
          settableOverride: true,
          slaveId: 1,
          slaveMonitor: false
        },
        eventDetectors: [],
        engineeringUnits: "",
        chartColour: null,
        chartRenderer: null,
        dataSourceXid: dataSourceId,
        defaultCacheSize: 1,
        deviceName: sede.nombre,
        discardExtremeValues: false,
        discardHighLimit: 1.7976931348623157e308,
        discardLowLimit: -1.7976931348623157e308,
        enabled: true,
        intervalLoggingPeriod: 15,
        name: `${sede.nombre}-coils-${i}`,
        purgePeriod: 1,
        textRenderer: {
          type: "PLAIN",
          suffix: ""
        },
        tolerance: 0.0
      });
      exportData.dataPoints.push({
        xid: `DP_${(Math.random() * 100000).toFixed(0)}`,
        loggingType: "NONE",
        intervalLoggingPeriodType: "MINUTES",
        intervalLoggingType: "INSTANT",
        purgeType: "YEARS",
        pointLocator: {
          range: "HOLDING_REGISTER",
          modbusDataType: "TWO_BYTE_INT_SIGNED",
          additive: 0.0,
          bit: 0,
          charset: "ASCII",
          multiplier: 1.0,
          offset: i,
          registerCount: 0,
          settableOverride: true,
          slaveId: 1,
          slaveMonitor: false
        },
        eventDetectors: [],
        engineeringUnits: "",
        chartColour: null,
        chartRenderer: null,
        dataSourceXid: dataSourceId,
        defaultCacheSize: 1,
        deviceName: sede.nombre,
        discardExtremeValues: false,
        discardHighLimit: 1.7976931348623157e308,
        discardLowLimit: -1.7976931348623157e308,
        enabled: true,
        intervalLoggingPeriod: 15,
        name: `${sede.nombre}-holding-${i}`,
        purgePeriod: 1,
        textRenderer: {
          type: "PLAIN",
          suffix: ""
        },
        tolerance: 0.0
      });
    }
    await redis.set("lastUsedPort", String(sede.port));

    client.subscribe(`${sede.nombre}/#`);
  }
  for (const http of config.httpRealTime.devices) {
    const dataSourceId = `DS_${(Math.random() * 100000).toFixed(0)}`;
    exportData.dataSources.push({
      xid: dataSourceId,
      type: "HTTP_RECEIVER",
      deviceIdWhiteList: ["mqtt", http.nombre],
      enabled: true,
      ipWhiteList: ["*.*.*.*"],
      name: http.nombre
    });
    for (const point of http.points) {
      exportData.dataPoints.push({
        xid: `DP_${(Math.random() * 100000).toFixed(0)}`,
        dataSourceXid: dataSourceId,
        name: point.name,
        deviceName: http.nombre,
        pointLocator: httpTemplates[point.type],
        loggingType: "NONE",
        intervalLoggingPeriodType: "MINUTES",
        intervalLoggingType: "INSTANT",
        purgeType: "YEARS",
        eventDetectors: [],
        engineeringUnits: "",
        chartColour: null,
        chartRenderer: null,
        defaultCacheSize: 1,
        discardExtremeValues: false,
        discardHighLimit: 1.7976931348623157e308,
        discardLowLimit: -1.7976931348623157e308,
        enabled: true,
        intervalLoggingPeriod: 15,
        purgePeriod: 1,
        textRenderer: {
          type: "PLAIN",
          suffix: ""
        },
        tolerance: 0.0
      });
    }
  }
  writeFile("importThisInVemetris.json", JSON.stringify(exportData));
};
if (require.main === module) {
  // ran with `node init.js`
  initialize();
}

/////////////////////////////////////////////////////////////////////
/////////////           Aqui comienza Modbus              ///////////
/////////////////////////////////////////////////////////////////////
/**
 * subscribe al servidor modbus a un topico(sede) en especifico
 *
 * @param sede - Objeto Sede el cual usara para devolver la data
 * @returns integer devuelve el puerto q se creo para esa sede
 * @public
 */
exports.subscribeTopicoModbus = async (topico) => {
  redis.incrBy("lastUsedPort", 1);
  const puerto = Number(await redis.get("lasUsedPort"));
  const data = {
    nombre: topico,
    puerto,
    rtu: new Array(256).fill({ ir: [], hr: [], dr: [], cr: [] })
  };
  initServerTCP(topico, puerto);
  client.subscribe(`${topico}/#`);
  return data;
};

/**
 * Inicia el servidor TCP-Modbus para una sede DADA
 *
 * @param sede - Objeto Sede el cual usara para devolver la data
 * @private
 */
function initServerTCP(sede, puerto) {
  // create an empty modbus client
  var ModbusRTU = require("modbus-serial");
  var vector = {
    setRegister: function (addr, value, unitID) {
      client.publish(`${sede}/${unitID}/setcoil/${addr}`, value);
    },
    setCoil: function (addr, state, unitID) {
      client.publish(`${sede}/${unitID}/setcoil/${addr}`, state);
    },
    getCoil: function (addr, unitID) {
      return new Promise(async (resolve) => {
        try {
          const coilData = Number(
            await redis.get(`${sede}/rtu/${unitID}/cr/${addr}`)
          );

          return resolve(coilData > 0 ? true : false);
        } catch (error) {
          resolve(false);
          console.error(error);
        }
      });
    },
    getInputRegister: function (addr, unitID) {
      return new Promise(async (resolve) => {
        try {
          const inputData = await redis.get(`${sede}/rtu/${unitID}/ir/${addr}`);
          return resolve(inputData ? Number(inputData) : 0);
        } catch (error) {
          resolve(0);
          return console.error(error);
        }
      });
    },
    getHoldingRegister: async function (addr, unitID) {
      return new Promise(async (resolve) => {
        try {
          const holdingData = await redis.get(
            `${sede}/rtu/${unitID}/hr/${addr}`
          );
          const toSend = holdingData
            ? Number(Number(holdingData).toFixed(0))
            : 0;
          return resolve(toSend);
        } catch (error) {
          resolve(0);
          return console.error(error);
        }
      });
    },
    getDiscreteInput: async function (addr, unitID) {
      return new Promise(async (resolve) => {
        try {
          const discreteInput = Number(
            await redis.get(`${sede}/rtu/${unitID}/dr/${addr}`)
          );
          return resolve(discreteInput > 0 ? true : false);
        } catch (error) {
          resolve(false);
          return console.error(error);
        }
      });
    }
  };
  // set the server to answer for modbus requests
  var serverTCP = new ModbusRTU.ServerTCP(vector, {
    host: "0.0.0.0",
    port: puerto,
    debug: true
  });
  serverTCP.on("initialized", function () {
    console.log(
      `initialized sede ${sede} en servidor modbus://0.0.0.0:${puerto}, espero topico de la forma ${sede}/RTU#/retype/addr#`
    );
  });

  serverTCP.on("socketError", function (err) {
    console.error(err);
    serverTCP.close(closed);
  });
}
