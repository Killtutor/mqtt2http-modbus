"use strict";
// MQTT import and clientConfig
const mqtt = require("mqtt");
const config = require("./config.json");
const client = mqtt.connect(
  `mqtt://${process.env.MQTT_HOST || config.mqttHost}:${
    process.env.MQTT_PORT || config.mqttPort
  }`,
  {
    password: process.env.MQTT_PASS || config.mqttPass,
    username: process.env.MQTT_USER || config.mqttUser
  }
);

client.on("connect", function () {
  console.info(
    "Modbus Conectado al broker. Subscrito a la configuracion inicial, para mas topicos usa el http server."
  );
});

function stringToCombinedASCII(str) {
  const combinedArray = [];
  for (let i = 0; i < str.length; i += 2) {
    let charCode1 = str.charCodeAt(i);
    let charCode2 = str.charCodeAt(i + 1);

    if (charCode1 > 127 || (i + 1 < str.length && charCode2 > 127)) {
      throw new Error("Character outside of ASCII range.");
    }

    if (i + 1 < str.length) {
      combinedArray.push((charCode1 << 8) | charCode2); // Combine two characters
    } else {
      combinedArray.push(charCode1 << 8); // Handle odd length strings
    }
  }
  return combinedArray;
}

function floatToByteArray(number) {
  const buffer = Buffer.alloc(4);
  buffer.writeFloatBE(number, 0);
  const byteArray = [];
  for (let i = 0; i < 4; i += 2) {
    byteArray.push(buffer.readUInt16BE(i));
  }
  return byteArray;
}

// REDIS import and Client Config
const { createClient } = require("redis");
const redis = createClient({
  url: config.redisUrl,
  name: "Modbus",
  // username: config.redisUser,
  password: process.env.REDIS_PASSWORD || config.redisPass
});
redis.on("error", (err) => console.log("Redis Client Error", err));
redis.connect();

// Modbus retType translator
const retTypeTranslator = {
  input: "ir",
  holding: "hr",
  discrete: "dr",
  coil: "cr",
  string: "hr"
};

//formato esperado de topico: sede/RTU#/retype/addr#
//retype could be input, coil, holding, discrete
let mensajes = 0;
client.on("message", async function (topic, message) {
  const proTopic = topic.split("/");
  if (proTopic[0] === "$SYS") {
    return;
  }
  const sede = proTopic[0];
  const RTU = parseInt(proTopic[1]);
  const retype = retTypeTranslator[proTopic[2]] ?? "ir";
  const addr = proTopic[3];
  let context = message ? message.toString("utf8") : "";
  context = ["0", "false", "falso", "False", "Falso"].includes(context)
    ? "0"
    : context;
  context = ["1", "true", "verdadero", "True", "Verdadero"].includes(context)
    ? "1"
    : context;
  if (proTopic[2] === "string") {
    const combinedASCII = stringToCombinedASCII(context);
    let c = 0;
    for (const ascii of combinedASCII) {
      await redis.set(
        `${sede}/rtu/${RTU}/${retype}/${Number(addr) + c}`,
        String(ascii)
      );
      c += 1;
    }
  } else if (retype === "hr") {
    console.log("hr", context, Number(context));
    const byteArray = floatToByteArray(Number(context));
    console.log("🚀 ~ byteArray:", byteArray);
    for (let i = 0; i < byteArray.length; i++) {
      await redis.set(
        `${sede}/rtu/${RTU}/${retype}/${Number(addr) + i}`,
        String(byteArray[i])
      );
    }
  } else {
    await redis.set(`${sede}/rtu/${RTU}/${retype}/${addr}`, String(context));
  }
  mensajes += 1;
  if (mensajes % 5000 === 0) {
    console.log("recibidos por cliente: ", mensajes);
  }
});
// Init Function, Runs once on server livespan
const initialize = async () => {
  client.subscribe("$SYS/#");
  for (const sede of config.modbusSedes) {
    console.log("🚀 ~ initialize ~ sede:", sede);
    initServerTCP(sede.nombre, sede.port);
    await redis.set("lastUsedPort", String(sede.port));
    client.subscribe(`${sede.nombre}/#`);
  }
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
          const toSend = holdingData ? Number(holdingData) : 0;
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
    serverTCP.close();
  });
}
