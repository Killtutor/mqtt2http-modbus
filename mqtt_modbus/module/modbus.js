"use strict";
// MQTT import and clientConfig
const mqtt = require("mqtt");
const config = require("./config.json");

// Message and error counters
let mensajes = 0;
let failedOperations = 0;

// Modbus retType translator
const retTypeTranslator = {
  input: "ir",
  holding: "hr",
  discrete: "dr",
  coil: "cr",
  string: "hr"
};

/**
 * Converts a string to combined ASCII values for modbus registers
 * @param {string} str - The string to convert
 * @returns {number[]} - Array of combined ASCII values
 */
function stringToCombinedASCII(str) {
  try {
    const combinedArray = [];
    for (let i = 0; i < str.length; i += 2) {
      let charCode1 = str.charCodeAt(i);
      let charCode2 = i + 1 < str.length ? str.charCodeAt(i + 1) : 0;

      if (charCode1 > 127 || (i + 1 < str.length && charCode2 > 127)) {
        throw new Error("Character outside of ASCII range.");
      }

      combinedArray.push((charCode1 << 8) | charCode2); // Combine two characters
    }
    return combinedArray;
  } catch (error) {
    console.error("Error in stringToCombinedASCII:", error.message);
    throw error;
  }
}

/**
 * Converts a float to byte array for modbus registers
 * @param {number} number - The float to convert
 * @returns {number[]} - Array of 16-bit values
 */
function floatToByteArray(number) {
  try {
    const buffer = Buffer.alloc(4);
    buffer.writeFloatBE(number, 0);
    const byteArray = [];
    for (let i = 0; i < 4; i += 2) {
      byteArray.push(buffer.readUInt16BE(i));
    }
    return byteArray;
  } catch (error) {
    console.error("Error in floatToByteArray:", error.message);
    throw error;
  }
}

// Create MQTT client with resilience options
const mqttClient = mqtt.connect(
  `mqtt://${process.env.MQTT_HOST || config.mqttHost}:${
    process.env.MQTT_PORT || config.mqttPort
  }`,
  {
    password: process.env.MQTT_PASS || config.mqttPass,
    username: process.env.MQTT_USER || config.mqttUser,
    clientId: `modbus_client_${Math.random().toString(16).slice(2, 8)}`,
    clean: true,
    reconnectPeriod: 5000, // Reconnect every 5 seconds
    connectTimeout: 10000, // 10 seconds timeout
    queueQoSZero: false
  }
);

// MQTT connection events
mqttClient.on("connect", function () {
  console.info(
    "Modbus conectado al broker. Subscrito a la configuracion inicial, para mas topicos usa el http server."
  );
  // Subscribe to topics after successful connection
  subscribeToTopics();
});

mqttClient.on("error", function (error) {
  console.error("MQTT client error:", error.message);
});

mqttClient.on("offline", function () {
  console.warn("MQTT client went offline, attempting to reconnect...");
});

mqttClient.on("reconnect", function () {
  console.info("MQTT client attempting to reconnect...");
});

// REDIS client setup with resilience features
const { createClient } = require("redis");
const redisClient = createClient({
  url: config.redisUrl,
  name: "Modbus",
  password: process.env.REDIS_PASSWORD || config.redisPass,
  socket: {
    reconnectStrategy: (retries) => {
      // Exponential backoff with max 10 second delay
      const delay = Math.min(Math.pow(2, retries) * 100, 10000);
      console.info(`Redis reconnecting after ${delay}ms (attempt ${retries})`);
      return delay;
    }
  }
});

// Redis connection events
redisClient.on("error", (err) => {
  console.error("Redis Client Error:", err.message);
  failedOperations++;
});

redisClient.on("reconnecting", () => {
  console.warn("Redis client reconnecting...");
});

redisClient.on("connect", () => {
  console.info("Redis client connected");
});

/**
 * Helper function to write to Redis with retries
 * @param {string} key - Redis key
 * @param {string} value - Value to store
 * @param {number} retries - Number of retries (default: 3)
 * @param {number} attempt - Current attempt (default: 0)
 * @returns {Promise<boolean>} - Success status
 */
async function redisSetWithRetry(key, value, retries = 3, attempt = 0) {
  try {
    await redisClient.set(key, value);
    return true;
  } catch (error) {
    if (attempt < retries) {
      const delay = Math.min(Math.pow(2, attempt) * 100, 5000);
      console.warn(
        `Retrying Redis set for ${key} after ${delay}ms (attempt ${
          attempt + 1
        }/${retries})`
      );
      await new Promise((resolve) => setTimeout(resolve, delay));
      return redisSetWithRetry(key, value, retries, attempt + 1);
    }
    console.error(
      `Failed to set Redis key ${key} after ${retries} attempts:`,
      error.message
    );
    failedOperations++;
    return false;
  }
}

/**
 * Helper function to read from Redis with retries
 * @param {string} key - Redis key
 * @param {number} retries - Number of retries (default: 3)
 * @param {number} attempt - Current attempt (default: 0)
 * @returns {Promise<string|null>} - Value or null if not found
 */
async function redisGetWithRetry(key, retries = 3, attempt = 0) {
  try {
    return await redisClient.get(key);
  } catch (error) {
    if (attempt < retries) {
      const delay = Math.min(Math.pow(2, attempt) * 100, 5000);
      console.warn(
        `Retrying Redis get for ${key} after ${delay}ms (attempt ${
          attempt + 1
        }/${retries})`
      );
      await new Promise((resolve) => setTimeout(resolve, delay));
      return redisGetWithRetry(key, retries, attempt + 1);
    }
    console.error(
      `Failed to get Redis key ${key} after ${retries} attempts:`,
      error.message
    );
    failedOperations++;
    return null;
  }
}

/**
 * Process incoming MQTT messages
 * @param {string} topic - MQTT topic
 * @param {Buffer} message - Message payload
 */
async function processMessage(topic, message) {
  try {
    // Check if this is a stats request
    if (topic === "modbus_module/stats/request") {
      mqttClient.publish(
        "modbus_module/stats/response",
        JSON.stringify({
          processedMessages: mensajes,
          failedOperations
        }),
        { qos: 1 }
      );
      return;
    }

    // Check if this is a reset request
    if (topic === "modbus_module/stats/reset") {
      mensajes = 0;
      failedOperations = 0;
      mqttClient.publish(
        "modbus_module/stats/response",
        JSON.stringify({
          processedMessages: mensajes,
          failedOperations,
          reset: true
        }),
        { qos: 1 }
      );
      return;
    }

    const proTopic = topic.split("/");
    if (proTopic[0] === "$SYS") {
      return;
    }

    const sede = proTopic[0];
    const RTU = parseInt(proTopic[1]);
    const retype = retTypeTranslator[proTopic[2]] ?? "ir";
    const addr = proTopic[3];

    if (isNaN(RTU)) {
      console.warn(`Invalid RTU number in topic: ${topic}`);
      return;
    }

    let context = message ? message.toString("utf8") : "";
    context = ["0", "false", "falso", "False", "Falso"].includes(context)
      ? "0"
      : context;
    context = ["1", "true", "verdadero", "True", "Verdadero"].includes(context)
      ? "1"
      : context;

    // Batch Redis operations for better performance
    const redisBatch = [];

    if (proTopic[2] === "string") {
      try {
        const combinedASCII = stringToCombinedASCII(context);
        for (let c = 0; c < combinedASCII.length; c++) {
          redisBatch.push({
            key: `${sede}/rtu/${RTU}/${retype}/${Number(addr) + c}`,
            value: String(combinedASCII[c])
          });
        }
      } catch (error) {
        console.error(
          `Error processing string value for ${topic}:`,
          error.message
        );
        failedOperations++;
        return;
      }
    } else if (retype === "hr") {
      try {
        const numValue = Number(context);
        if (isNaN(numValue)) {
          console.warn(`Invalid number for topic ${topic}: ${context}`);
          return;
        }

        const byteArray = floatToByteArray(numValue);
        for (let i = 0; i < byteArray.length; i++) {
          redisBatch.push({
            key: `${sede}/rtu/${RTU}/${retype}/${Number(addr) + i}`,
            value: String(byteArray[i])
          });
        }
      } catch (error) {
        console.error(
          `Error processing float value for ${topic}:`,
          error.message
        );
        failedOperations++;
        return;
      }
    } else {
      redisBatch.push({
        key: `${sede}/rtu/${RTU}/${retype}/${addr}`,
        value: String(context)
      });
    }

    // Execute all Redis operations
    const results = await Promise.allSettled(
      redisBatch.map((item) => redisSetWithRetry(item.key, item.value))
    );

    const failedCount = results.filter(
      (r) => r.status === "rejected" || (r.status === "fulfilled" && !r.value)
    ).length;

    if (failedCount > 0) {
      console.warn(
        `${failedCount}/${redisBatch.length} Redis operations failed for topic ${topic}`
      );
      failedOperations += failedCount;
    }

    if (failedCount < redisBatch.length) {
      // At least one operation succeeded
      mensajes += 1;
    }
  } catch (error) {
    console.error(
      `Error processing message for topic ${topic}:`,
      error.message
    );
    failedOperations++;
  }
}

// Register the message handler
mqttClient.on("message", processMessage);

/**
 * Subscribe to all configured topics
 */
function subscribeToTopics() {
  try {
    // Subscribe to stats topics
    mqttClient.subscribe("modbus_module/stats/request", { qos: 1 });
    mqttClient.subscribe("modbus_module/stats/reset", { qos: 1 });
    mqttClient.subscribe("$SYS/#", { qos: 0 });

    // Subscribe to device topics
    for (const sede of config.modbusSedes) {
      mqttClient.subscribe(`${sede.nombre}/#`, { qos: 1 });
      console.info(`Subscribed to ${sede.nombre}/#`);
    }
  } catch (error) {
    console.error("Error subscribing to topics:", error.message);
  }
}

/**
 * Initialize the Redis connection
 */
async function connectRedis() {
  try {
    await redisClient.connect();
    console.info("Redis client connected successfully");
  } catch (error) {
    console.error("Failed to connect to Redis:", error.message);
    setTimeout(connectRedis, 5000);
  }
}

/**
 * Initialize the application
 */
const initialize = async () => {
  try {
    await connectRedis();

    // Initialize modbus servers for each sede
    for (const sede of config.modbusSedes) {
      console.info(
        `Initializing Modbus server for ${sede.nombre} on port ${sede.port}`
      );
      initServerTCP(sede.nombre, sede.port);
      await redisSetWithRetry("lastUsedPort", String(sede.port));
    }

    // Publish stats periodically
    setInterval(() => {
      mqttClient.publish(
        "modbus_module/stats",
        JSON.stringify({
          processedMessages: mensajes,
          failedOperations
        }),
        { qos: 1 }
      );
    }, 30000); // every 30 seconds

    console.info("Modbus service initialized successfully");
  } catch (error) {
    console.error("Failed to initialize modbus service:", error.message);
    process.exit(1);
  }
};

/**
 * subscribe al servidor modbus a un topico(sede) en especifico
 *
 * @param {string} topico - Topico/sede to subscribe to
 * @returns {object} - Configuration object with port
 * @public
 */
exports.subscribeTopicoModbus = async (topico) => {
  try {
    const lastPortStr = await redisGetWithRetry("lastUsedPort");
    if (!lastPortStr) {
      throw new Error("Could not get lastUsedPort from Redis");
    }

    await redisClient.incrBy("lastUsedPort", 1);
    const puerto = Number(await redisGetWithRetry("lastUsedPort"));

    const data = {
      nombre: topico,
      puerto,
      rtu: new Array(256).fill({ ir: [], hr: [], dr: [], cr: [] })
    };

    initServerTCP(topico, puerto);
    mqttClient.subscribe(`${topico}/#`, { qos: 1 });
    console.info(`Subscribed to new topic: ${topico}/#`);

    return data;
  } catch (error) {
    console.error(
      `Failed to subscribe to Modbus topic ${topico}:`,
      error.message
    );
    failedOperations++;
    throw error;
  }
};

// Active servers tracking
const activeServers = new Map();

/**
 * Inicia el servidor TCP-Modbus para una sede DADA
 *
 * @param {string} sede - Nombre de la sede
 * @param {number} puerto - Puerto para el servidor
 * @private
 */
function initServerTCP(sede, puerto) {
  try {
    // Close existing server for this sede if exists
    if (activeServers.has(sede)) {
      try {
        const existingServer = activeServers.get(sede);
        existingServer.close();
        console.info(`Closed existing Modbus server for ${sede}`);
      } catch (error) {
        console.warn(
          `Error closing existing server for ${sede}:`,
          error.message
        );
      }
    }

    // create an empty modbus client
    var ModbusRTU = require("modbus-serial");
    var vector = {
      setRegister: function (addr, value, unitID) {
        try {
          console.info(
            `setRegister ${sede}/${unitID}/setcoil/${addr} ${value}`
          );
          mqttClient.publish(
            `${sede}/${unitID}/setcoil/${addr}`,
            String(value),
            {
              qos: 1
            }
          );
        } catch (error) {
          console.error(
            `Error in setRegister for ${sede}/${unitID}/setcoil/${addr}:`,
            error.message
          );
          failedOperations++;
        }
      },
      setCoil: function (addr, state, unitID) {
        try {
          console.info(`setCoil ${sede}/${unitID}/setcoil/${addr} ${state}`);
          mqttClient.publish(
            `${sede}/${unitID}/setcoil/${addr}`,
            String(state),
            {
              qos: 1
            }
          );
        } catch (error) {
          console.error(
            `Error in setCoil for ${sede}/${unitID}/setcoil/${addr}:`,
            error.message
          );
          failedOperations++;
        }
      },
      getCoil: async function (addr, unitID) {
        try {
          const key = `${sede}/rtu/${unitID}/cr/${addr}`;
          const coilData = await redisGetWithRetry(key);
          return coilData ? Number(coilData) > 0 : false;
        } catch (error) {
          console.error(
            `Error in getCoil for ${sede}/rtu/${unitID}/cr/${addr}:`,
            error.message
          );
          failedOperations++;
          return false;
        }
      },
      getInputRegister: async function (addr, unitID) {
        try {
          const key = `${sede}/rtu/${unitID}/ir/${addr}`;
          const inputData = await redisGetWithRetry(key);
          return inputData ? Number(inputData) : 0;
        } catch (error) {
          console.error(
            `Error in getInputRegister for ${sede}/rtu/${unitID}/ir/${addr}:`,
            error.message
          );
          failedOperations++;
          return 0;
        }
      },
      getHoldingRegister: async function (addr, unitID) {
        try {
          const key = `${sede}/rtu/${unitID}/hr/${addr}`;
          const holdingData = await redisGetWithRetry(key);
          return holdingData ? Number(holdingData) : 0;
        } catch (error) {
          console.error(
            `Error in getHoldingRegister for ${sede}/rtu/${unitID}/hr/${addr}:`,
            error.message
          );
          failedOperations++;
          return 0;
        }
      },
      getDiscreteInput: async function (addr, unitID) {
        try {
          const key = `${sede}/rtu/${unitID}/dr/${addr}`;
          const discreteInput = await redisGetWithRetry(key);
          return discreteInput ? Number(discreteInput) > 0 : false;
        } catch (error) {
          console.error(
            `Error in getDiscreteInput for ${sede}/rtu/${unitID}/dr/${addr}:`,
            error.message
          );
          failedOperations++;
          return false;
        }
      }
    };

    // set the server to answer for modbus requests
    var serverTCP = new ModbusRTU.ServerTCP(vector, {
      host: "0.0.0.0",
      port: puerto,
      debug: true
    });

    // Store server reference
    activeServers.set(sede, serverTCP);

    // Server event handlers
    serverTCP.on("initialized", function () {
      console.info(
        `Initialized sede ${sede} en servidor modbus://0.0.0.0:${puerto}, espero topico de la forma ${sede}/RTU#/retype/addr#`
      );
    });

    serverTCP.on("socketError", function (err) {
      console.error(`Socket error in Modbus server for ${sede}:`, err.message);
      failedOperations++;

      // Attempt to restart the server after a delay
      setTimeout(() => {
        try {
          console.info(`Attempting to restart Modbus server for ${sede}...`);
          serverTCP.close();
          initServerTCP(sede, puerto);
        } catch (restartError) {
          console.error(
            `Failed to restart Modbus server for ${sede}:`,
            restartError.message
          );
        }
      }, 5000);
    });

    return serverTCP;
  } catch (error) {
    console.error(
      `Failed to initialize Modbus server for ${sede}:`,
      error.message
    );
    failedOperations++;
    throw error;
  }
}

// Graceful shutdown handling
process.on("SIGTERM", async () => {
  console.info("SIGTERM signal received. Closing connections...");
  await shutdown();
});

process.on("SIGINT", async () => {
  console.info("SIGINT signal received. Closing connections...");
  await shutdown();
});

/**
 * Graceful shutdown function
 */
async function shutdown() {
  try {
    // Close all Modbus servers
    for (const [sede, server] of activeServers.entries()) {
      try {
        server.close();
        console.info(`Closed Modbus server for ${sede}`);
      } catch (error) {
        console.warn(`Error closing Modbus server for ${sede}:`, error.message);
      }
    }

    // Disconnect MQTT client
    mqttClient.end(true);
    console.info("MQTT client disconnected");

    // Disconnect Redis client
    await redisClient.quit();
    console.info("Redis client disconnected");

    console.info("Shutdown complete");
  } catch (error) {
    console.error("Error during shutdown:", error.message);
  } finally {
    process.exit(0);
  }
}

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

if (require.main === module) {
  // ran with `node init.js`
  initialize().catch((error) => {
    console.error("Failed to initialize modbus module:", error.message);
  });
}
