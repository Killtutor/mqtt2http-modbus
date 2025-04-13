"use strict";

const mqtt = require("mqtt");
const { performance } = require("perf_hooks");
const pidusage = require("pidusage");
const config = require("./config.json");
const fs = require("fs");
const path = require("path");

// Find the first sede in config
const firstSede = config.modbusSedes[0];
// --- Configuration ---
const MESSAGE_TYPES_HTTP = ["boolean", "numero", "string", "json"];
const MESSAGE_TYPES_MODBUS = ["input", "holding", "string"];
const HTTP_TOPIC_TEMPLATE = "PDVSA_SEDE1_http/{msg_type}"; // Topic template
const MODBUS_TOPIC_TEMPLATE = `${firstSede.nombre}/1/{msg_type}/0`; // Topic template
const STRING_PAYLOAD_LENGTH = 100; // Length for 'cadena' type
const MONITOR_INTERVAL = 1000; // ms for CPU/Mem sampling

// --- Globals ---
let publishLatencies = {}; // { type: [latencies] }
let cpuUsage = [];
let memoryUsage = [];
let monitoringIntervalId = null;
let testResults = []; // To store results for file output
let currentTestType = ""; // To track whether we're testing HTTP or MODBUS

// --- File Output ---
const timestamp = new Date()
  .toISOString()
  .replace(/:/g, "-")
  .replace(/\..+/, "");
const resultsDir = path.join(__dirname, "results");
const resultsFilename = `message_types_results_${timestamp}.csv`;
const resultsPath = path.join(resultsDir, resultsFilename);

// Ensure results directory exists
function setupResultsDirectory() {
  if (!fs.existsSync(resultsDir)) {
    fs.mkdirSync(resultsDir, { recursive: true });
  }
  // Create CSV header
  const header =
    "Interface,MessageType,Latency_avg_ms,Messages_per_sec,CPU_avg_percent,Memory_avg_MB\n";
  fs.writeFileSync(resultsPath, header);
  console.info(`Results will be saved to: ${resultsPath}`);
}

// Function to save a single test result
function saveTestResult(
  messageType,
  latencyAvg,
  messagesPerSec,
  cpuAvg,
  memAvg
) {
  const resultLine = `${currentTestType},${messageType},${latencyAvg.toFixed(
    2
  )},${messagesPerSec.toFixed(2)},${cpuAvg.toFixed(2)},${memAvg.toFixed(2)}\n`;
  fs.appendFileSync(resultsPath, resultLine);
}

// Initialize MQTT client
function createMqttClient() {
  return mqtt.connect(
    `mqtt://${process.env.MQTT_HOST || config.mqttHost}:${
      process.env.MQTT_PORT || config.mqttPort
    }`,
    {
      password: process.env.MQTT_PASS || config.mqttPass,
      username: process.env.MQTT_USER || config.mqttUser
    }
  );
}

function generatePayload(msgType) {
  switch (msgType) {
    case "boolean":
    case "input":
      return Buffer.from(Math.random() < 0.5 ? "true" : "false");
    case "numero":
    case "holding":
      // Ensure it's a valid number string
      return Buffer.from(String(Math.random() * 2000 - 1000));
    case "string":
      return `Probando PERFORMANCE MMLO, en HTTP y MODBUS`;
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

async function publishTypedMessages(client, topic, numMessages, msgType) {
  const localLatencies = [];

  for (let i = 0; i < numMessages; i++) {
    const messagePayload = generatePayload(msgType);
    const pubStartTime = performance.now();
    try {
      await client.publish(topic, messagePayload);

      const pubEndTime = performance.now();
      localLatencies.push(pubEndTime - pubStartTime);
    } catch (error) {
      // Stop this client's test for this type on error
      continue;
    }
  }
  // Add latencies for this type
  if (!publishLatencies[msgType]) publishLatencies[msgType] = [];
  publishLatencies[msgType].push(...localLatencies);
}

async function monitorPerformance(targetPid) {
  if (!targetPid) return;
  try {
    const stats = await pidusage(targetPid);
    cpuUsage.push(stats.cpu);
    memoryUsage.push(stats.memory / 1024 / 1024); // MB
  } catch (error) {
    if (error.message.includes("No matching pid found")) {
      if (monitoringIntervalId) clearInterval(monitoringIntervalId);
      monitoringIntervalId = null;
    } else {
      console.error(`Error monitoring PID ${targetPid}:`, error);
    }
  }
}

function startMonitoring(targetPid) {
  if (monitoringIntervalId) clearInterval(monitoringIntervalId);
  cpuUsage = [];
  memoryUsage = [];
  // Run once immediately to start collecting data
  monitorPerformance(targetPid);
  monitoringIntervalId = setInterval(
    () => monitorPerformance(targetPid),
    MONITOR_INTERVAL
  );
}

function stopMonitoring(targetPid) {
  if (monitoringIntervalId) {
    clearInterval(monitoringIntervalId);
    monitoringIntervalId = null;
    // Run one final time to capture end state
    return monitorPerformance(targetPid);
  }
  return Promise.resolve();
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

async function runTestForMessageType(
  msgType,
  devices,
  msgs_per_type,
  targetPid,
  http
) {
  publishLatencies[msgType] = []; // Reset latencies for this type
  startMonitoring(targetPid);
  const testStartTime = performance.now();
  const devicePromises = [];

  for (let i = 0; i < devices; i++) {
    const topic = http
      ? HTTP_TOPIC_TEMPLATE.replace("{msg_type}", msgType)
      : MODBUS_TOPIC_TEMPLATE.replace("{msg_type}", msgType);

    const deviceTask = async () => {
      let client;
      try {
        client = await createMqttClient();
        await publishTypedMessages(client, topic, msgs_per_type, msgType);
      } catch (err) {
        console.error(
          `Device ${client?.options?.clientId}: Failed during test - ${err.message}`
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
  await stopMonitoring(targetPid);

  // --- Calculate Metrics for this type ---
  const totalDurationSec = (testEndTime - testStartTime) / 1000;

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

  console.info(
    `| ${String(msgType).padEnd(12)} | ${latencyStats.avg
      .toFixed(2)
      .padEnd(15)} | ${avgMsgPerSec.toFixed(2).padEnd(15)} | ${avgCpu
      .toFixed(2)
      .padEnd(12)} | ${avgMem.toFixed(2).padEnd(15)} |`
  );

  // Save to file
  saveTestResult(msgType, latencyStats.avg, avgMsgPerSec, avgCpu, avgMem);

  await new Promise((resolve) => setTimeout(resolve, 2000)); // Pause between types
}

async function runAllTypeTests(
  devices = 5,
  msgs_per_type = 100,
  targetPid = null,
  http = true
) {
  // Set current test type
  currentTestType = http ? "HTTP" : "MODBUS";

  console.info("--- MQTT Scalability Test (Message Type) ---");
  console.info(`Simulating ${devices} devices.`);
  console.info(`Messages per type per device: ${msgs_per_type}`);
  console.info(`Target PID: ${targetPid} ${http ? "HTTP" : "MODBUS"}`);
  console.info(`Waiting 5 seconds before starting tests...`);

  // Add 5 second timeout before starting tests
  await new Promise((resolve) => setTimeout(resolve, 15000));

  console.info("-".repeat(85));
  console.info(
    "| Tipo Mensaje | Latencia avg(ms) | Mensajes/s avg | CPU avg (%) | Memoria avg (MB) |"
  );
  console.info(
    "|--------------|-----------------|-----------------|--------------|-----------------|"
  );

  for (const type of http ? MESSAGE_TYPES_HTTP : MESSAGE_TYPES_MODBUS) {
    await runTestForMessageType(type, devices, msgs_per_type, targetPid, http);
  }

  console.info("-".repeat(75));
  console.info(`${currentTestType} tests complete.`);
}

// --- Execute ---
// Execute the scalability tests if this script is run directly
if (require.main === module) {
  const args = process.argv.slice(2);
  const httpPid = parseInt(args[0], 10);
  const modbusPid = parseInt(args[1], 10);

  if (!httpPid || !modbusPid) {
    console.error("Usage: node scalability.js <httpPid> <modbusPid>");
    process.exit(1);
  }

  // Setup results directory and file
  setupResultsDirectory();

  // Run HTTP tests first, then Modbus tests
  (async () => {
    try {
      await runAllTypeTests(10, 300, httpPid, true);
      await runAllTypeTests(10, 300, modbusPid, false);
      console.info(`Full results saved to: ${resultsPath}`);
      process.exit(0);
    } catch (err) {
      console.error("Error running tests:", err);
      process.exit(1);
    }
  })();
}

module.exports = {
  runAllTypeTests
};

// Optional: Handle Ctrl+C
process.on("SIGINT", () => {
  console.log("\nCaught interrupt signal. Shutting down...");
  stopMonitoring();
  process.exit(0);
});
