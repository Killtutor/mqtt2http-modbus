"use strict";

const mqtt = require("mqtt");
const { performance } = require("perf_hooks");
const pidusage = require("pidusage");
const config = require("./config.json");
const yargs = require("yargs/yargs");
const { hideBin } = require("yargs/helpers");
const os = require("os");
const crypto = require("crypto"); // For generating random strings

// --- Configuration ---
const DEFAULT_DEVICES = 5;
const DEFAULT_MESSAGES_PER_TYPE = 100; // Number of messages each device sends *per type*
const MESSAGE_TYPES = ["boolean", "numero", "cadena", "json"];
const TEST_TOPIC_TEMPLATE = "test/device/{device_id}/typed_data"; // Topic template
const CLIENT_ID_TEMPLATE =
  "scalability-tester-mt-{type}-{device_id}-{timestamp}"; // Unique client ID
const DEFAULT_QOS = 1;
const STRING_PAYLOAD_LENGTH = 100; // Length for 'cadena' type
const MONITOR_INTERVAL = 1000; // ms for CPU/Mem sampling

// --- Globals ---
let publishLatencies = {}; // { type: [latencies] }
let cpuUsage = [];
let memoryUsage = [];
let monitoringIntervalId = null;
let targetPid = null; // PID of the process being monitored

// --- Argument Parsing ---
const argv = yargs(hideBin(process.argv))
  .option("broker", {
    alias: "b",
    type: "string",
    description: "MQTT broker address",
    default: process.env.MQTT_HOST || config.mqttHost || "localhost"
  })
  .option("port", {
    alias: "p",
    type: "number",
    description: "MQTT broker port",
    default: process.env.MQTT_PORT || config.mqttPort || 1883
  })
  .option("user", {
    alias: "u",
    type: "string",
    description: "MQTT user",
    default: process.env.MQTT_USER || config.mqttUser
  })
  .option("password", {
    alias: "P",
    type: "string",
    description: "MQTT password",
    default: process.env.MQTT_PASS || config.mqttPass
  })
  .option("devices", {
    alias: "d",
    type: "number",
    description: "Number of concurrent devices",
    default: DEFAULT_DEVICES
  })
  .option("msgs_per_type", {
    alias: "m",
    type: "number",
    description: "Messages per device for each type",
    default: DEFAULT_MESSAGES_PER_TYPE
  })
  .option("pid", {
    type: "number",
    description: "PID of the target process to monitor",
    demandOption: true
  })
  .help().argv;

const mqttConnection = `mqtt://${argv.broker}:${argv.port}`;
const mqttCredentials = {
  clientId: `test-runner-mt-${Date.now()}`,
  username: argv.user,
  password: argv.password
};

console.log(`Connecting to MQTT: ${mqttConnection}`);
targetPid = argv.pid;
console.log(`Monitoring PID: ${targetPid}`);

// --- Helper Functions ---

function connectMqtt(clientIdSuffix) {
  const uniqueClientId = clientIdSuffix; // Suffix already includes type/device/ts
  const clientOptions = {
    ...mqttCredentials,
    clientId: uniqueClientId
  };
  return new Promise((resolve, reject) => {
    const client = mqtt.connect(mqttConnection, clientOptions);
    client.on("connect", () => {
      resolve(client);
    });
    client.on("error", (err) => {
      console.error(`${uniqueClientId}: Connection error:`, err);
      client.end();
      reject(err);
    });
    client.on("offline", () =>
      console.warn(`${uniqueClientId}: Client went offline.`)
    );
    client.on("reconnect", () =>
      console.warn(`${uniqueClientId}: Reconnecting...`)
    );
  });
}

function generatePayload(msgType) {
  switch (msgType) {
    case "boolean":
      return Buffer.from(Math.random() < 0.5 ? "true" : "false");
    case "numero":
      // Ensure it's a valid number string
      return Buffer.from(String(Math.random() * 2000 - 1000));
    case "cadena":
      return crypto.randomBytes(STRING_PAYLOAD_LENGTH);
    case "json":
      return Buffer.from(
        JSON.stringify({
          sensor_id: `sensor_${Math.floor(Math.random() * 100)}`,
          value: Math.random() * 100,
          timestamp: Date.now(),
          status: ["active", "inactive", "error"][Math.floor(Math.random() * 3)]
        })
      );
    default:
      return Buffer.from("unknown_type");
  }
}

async function publishTypedMessages(client, topic, msgType, numMessages) {
  const clientIdentifier = client.options.clientId;
  const localLatencies = [];

  for (let i = 0; i < numMessages; i++) {
    const messagePayload = generatePayload(msgType);
    const pubStartTime = performance.now();
    try {
      await new Promise((resolve, reject) => {
        client.publish(topic, messagePayload, { qos: DEFAULT_QOS }, (err) => {
          if (err) {
            console.error(
              `${clientIdentifier}: Publish error (${msgType}):`,
              err
            );
            reject(err);
          } else {
            const pubEndTime = performance.now();
            localLatencies.push(pubEndTime - pubStartTime);
            resolve();
          }
        });
      });
    } catch (error) {
      // Stop this client's test for this type on error
      break;
    }
  }
  // Add latencies for this type
  if (!publishLatencies[msgType]) publishLatencies[msgType] = [];
  publishLatencies[msgType].push(...localLatencies);
}

async function monitorPerformance() {
  if (!targetPid) return;
  try {
    const stats = await pidusage(targetPid);
    cpuUsage.push(stats.cpu);
    memoryUsage.push(stats.memory / 1024 / 1024); // MB
  } catch (error) {
    if (error.message.includes("No matching pid found")) {
      console.warn(`Monitor: PID ${targetPid} not found. Stopping.`);
      if (monitoringIntervalId) clearInterval(monitoringIntervalId);
      monitoringIntervalId = null;
    } else {
      console.error(`Monitor: Error PID ${targetPid}:`, error);
    }
  }
}

function startMonitoring() {
  if (monitoringIntervalId) clearInterval(monitoringIntervalId);
  cpuUsage = [];
  memoryUsage = [];
  monitoringIntervalId = setInterval(monitorPerformance, MONITOR_INTERVAL);
  console.log(`Started monitoring PID ${targetPid}...`);
}

function stopMonitoring() {
  if (monitoringIntervalId) {
    clearInterval(monitoringIntervalId);
    monitoringIntervalId = null;
    console.log("Stopped monitoring.");
  }
}

function calculateStats(array) {
  if (!array || array.length === 0)
    return { avg: 0, min: 0, max: 0, p95: 0, count: 0 };
  const sorted = [...array].sort((a, b) => a - b);
  const sum = sorted.reduce((a, b) => a + b, 0);
  const avg = sum / sorted.length;
  const min = sorted[0];
  const max = sorted[sorted.length - 1];
  const p95Index = Math.max(0, Math.ceil(sorted.length * 0.95) - 1);
  const p95 = sorted[p95Index];
  return { avg, min, max, p95, count: sorted.length };
}

// --- Main Test Logic ---

async function runTestForMessageType(msgType) {
  console.log(
    `\n--- Running test: ${argv.devices} devices, ${argv.msgs_per_type} messages each, type: ${msgType} ---`
  );
  publishLatencies[msgType] = []; // Reset latencies for this type

  startMonitoring();
  const testStartTime = performance.now();
  const devicePromises = [];

  for (let i = 0; i < argv.devices; i++) {
    const deviceId = `device-${i}`;
    const uniqueClientId = CLIENT_ID_TEMPLATE.replace("{type}", msgType)
      .replace("{device_id}", deviceId)
      .replace("{timestamp}", Date.now());
    const topic = TEST_TOPIC_TEMPLATE.replace("{device_id}", deviceId);

    const deviceTask = async () => {
      let client;
      try {
        client = await connectMqtt(uniqueClientId);
        await publishTypedMessages(client, topic, msgType, argv.msgs_per_type);
      } catch (err) {
        console.error(
          `Device ${uniqueClientId}: Failed during test - ${err.message}`
        );
      } finally {
        if (client && client.connected) {
          client.end();
        }
      }
    };
    devicePromises.push(deviceTask());
    // await new Promise(resolve => setTimeout(resolve, 20)); // Stagger slightly
  }

  await Promise.allSettled(devicePromises);

  const testEndTime = performance.now();
  stopMonitoring();

  // --- Calculate Metrics for this type ---
  const totalDurationSec = (testEndTime - testStartTime) / 1000;
  const totalMessagesSent = argv.msgs_per_type * argv.devices; // Ideal total

  const latencyStats = calculateStats(publishLatencies[msgType] || []);
  const actualMessagesSent = latencyStats.count;
  const avgMsgPerSec = actualMessagesSent / totalDurationSec || 0;
  const avgCpu =
    cpuUsage.length > 0
      ? cpuUsage.reduce((a, b) => a + b, 0) / cpuUsage.length
      : 0;
  const avgMem =
    memoryUsage.length > 0
      ? memoryUsage.reduce((a, b) => a + b, 0) / memoryUsage.length
      : 0;

  console.log(
    `| ${String(msgType).padEnd(12)} | ${latencyStats.avg
      .toFixed(2)
      .padEnd(15)} | ${avgMsgPerSec.toFixed(2).padEnd(15)} | ${avgCpu
      .toFixed(2)
      .padEnd(12)} | ${avgMem.toFixed(2).padEnd(15)} |`
  );

  await new Promise((resolve) => setTimeout(resolve, 2000)); // Pause between types
}

async function runAllTypeTests() {
  console.log("--- MQTT Scalability Test (Message Type) ---");
  console.log(`Broker: ${argv.broker}:${argv.port}`);
  console.log(`Simulating ${argv.devices} devices.`);
  console.log(`Messages per type per device: ${argv.msgs_per_type}`);
  console.log(`Target PID: ${targetPid}`);
  console.log("-" * 75);
  console.log(
    "| {:<12} | {:<15} | {:<15} | {:<12} | {:<15} |".format(
      "Tipo Mensaje",
      "Latencia avg(ms)",
      "Mensajes/s avg",
      "CPU avg (%)",
      "Memoria avg (MB)"
    )
  );
  console.log(
    "|--------------|-----------------|-----------------|--------------|-----------------|"
  );

  for (const type of MESSAGE_TYPES) {
    await runTestForMessageType(type);
  }

  console.log("-" * 75);
  console.log("All tests complete.");
  process.exit(0);
}

// --- Execute ---
runAllTypeTests().catch((err) => {
  console.error("Test suite failed:", err);
  process.exit(1);
});

// Optional: Handle Ctrl+C
process.on("SIGINT", () => {
  console.log("\nCaught interrupt signal. Shutting down...");
  stopMonitoring();
  process.exit(0);
});

// Helper for basic string formatting (like Python's .format)
String.prototype.format = function (...args) {
  let i = 0;
  return this.replace(/{.*?}/g, (match) =>
    typeof args[i] !== "undefined" ? args[i++] : match
  );
};
