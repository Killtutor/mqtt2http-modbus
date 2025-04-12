"use strict";

const mqtt = require("mqtt");
const { performance } = require("perf_hooks");
const pidusage = require("pidusage");
const config = require("./config.json");
const yargs = require("yargs/yargs");
const { hideBin } = require("yargs/helpers");
const os = require("os"); // Required for CPU monitoring alternative

// --- Configuration ---
const DEFAULT_DEVICES = 5;
const MESSAGE_COUNTS = [10, 50, 100, 200];
const TEST_TOPIC_TEMPLATE = "test/device/{device_id}/data"; // Topic template
const CLIENT_ID_TEMPLATE = "scalability-tester-mc-{device_id}-{timestamp}"; // Unique client ID
const DEFAULT_QOS = 1;
const MONITOR_INTERVAL = 1000; // ms for CPU/Mem sampling

// --- Globals ---
let publishLatencies = []; // Array to store publish latencies for calculation
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
  .option("pid", {
    type: "number",
    description:
      "PID of the target process to monitor (e.g., MQTT broker or bridge)",
    demandOption: true // Make PID required
  })
  .help().argv;

const mqttConnection = `mqtt://${argv.broker}:${argv.port}`;
const mqttCredentials = {
  clientId: `test-runner-mc-${Date.now()}`, // Unique ID for the test runner itself
  username: argv.user,
  password: argv.password
};

console.log(`Connecting to MQTT: ${mqttConnection}`);
targetPid = argv.pid;
console.log(`Monitoring PID: ${targetPid}`);

// --- Helper Functions ---

function connectMqtt(clientIdSuffix) {
  const uniqueClientId = CLIENT_ID_TEMPLATE.replace(
    "{device_id}",
    clientIdSuffix
  ).replace("{timestamp}", Date.now());
  const clientOptions = {
    ...mqttCredentials,
    clientId: uniqueClientId
  };
  return new Promise((resolve, reject) => {
    const client = mqtt.connect(mqttConnection, clientOptions);
    client.on("connect", () => {
      // console.log(`${uniqueClientId}: Connected`); // Reduce noise
      resolve(client);
    });
    client.on("error", (err) => {
      console.error(`${uniqueClientId}: Connection error:`, err);
      client.end(); // Clean up
      reject(err);
    });
    client.on("offline", () => {
      console.warn(`${uniqueClientId}: Client went offline.`);
      // Optionally handle reconnection or failure
    });
    client.on("reconnect", () => {
      console.warn(`${uniqueClientId}: Reconnecting...`);
    });
  });
}

async function publishMessages(client, deviceId, topic, numMessages) {
  const clientIdentifier = client.options.clientId; // Get the unique client ID
  const localLatencies = [];
  const basePayload = { value: "test_payload", ts: 0 }; // Basic payload

  // console.log(`${clientIdentifier}: Publishing ${numMessages} messages to ${topic}...`); // Reduce noise
  const startPubTime = performance.now();

  for (let i = 0; i < numMessages; i++) {
    const messagePayload = JSON.stringify({ ...basePayload, ts: Date.now() });
    const pubStartTime = performance.now();
    try {
      await new Promise((resolve, reject) => {
        client.publish(topic, messagePayload, { qos: DEFAULT_QOS }, (err) => {
          if (err) {
            console.error(`${clientIdentifier}: Publish error:`, err);
            reject(err); // Reject on error
          } else {
            const pubEndTime = performance.now();
            localLatencies.push(pubEndTime - pubStartTime);
            resolve(); // Resolve on success
          }
        });
      });
      // await new Promise(resolve => setTimeout(resolve, 1)); // Small artificial delay if needed
    } catch (error) {
      // Error already logged in the promise rejection
      // Decide if we should continue or stop the test for this client
      break; // Stop publishing for this client on error
    }
  }

  const endPubTime = performance.now();
  const totalPubDuration = endPubTime - startPubTime;
  // console.log(`${clientIdentifier}: Finished ${numMessages} messages in ${totalPubDuration.toFixed(2)}ms.`); // Reduce noise

  // Add latencies to global array (needs locking in concurrent env, but JS is single-threaded for this part)
  publishLatencies.push(...localLatencies);
}

async function monitorPerformance() {
  if (!targetPid) {
    console.warn("No target PID specified for monitoring.");
    return;
  }
  try {
    const stats = await pidusage(targetPid);
    cpuUsage.push(stats.cpu);
    memoryUsage.push(stats.memory / 1024 / 1024); // Convert to MB
  } catch (error) {
    // Handle cases where PID doesn't exist anymore
    if (error.message.includes("No matching pid found")) {
      console.warn(`Monitor: PID ${targetPid} not found. Stopping monitoring.`);
      if (monitoringIntervalId) clearInterval(monitoringIntervalId);
      monitoringIntervalId = null;
    } else {
      console.error(`Monitor: Error monitoring PID ${targetPid}:`, error);
    }
  }
}

function startMonitoring() {
  if (monitoringIntervalId) clearInterval(monitoringIntervalId); // Clear previous interval if any
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
    // Run one last time to capture final state? Maybe not necessary.
    // await monitorPerformance();
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

async function runTestForMessageCount(numMessages) {
  console.log(
    `\n--- Running test: ${argv.devices} devices, ${numMessages} messages each ---`
  );
  publishLatencies = []; // Reset latencies for this run

  startMonitoring();
  const testStartTime = performance.now();
  const devicePromises = [];

  for (let i = 0; i < argv.devices; i++) {
    const deviceId = `device-${i}`;
    const topic = TEST_TOPIC_TEMPLATE.replace("{device_id}", deviceId);

    const deviceTask = async () => {
      let client;
      try {
        client = await connectMqtt(deviceId);
        await publishMessages(client, deviceId, topic, numMessages);
      } catch (err) {
        console.error(
          `Device ${deviceId}: Failed during test - ${err.message}`
        );
      } finally {
        if (client && client.connected) {
          client.end();
        }
      }
    };
    devicePromises.push(deviceTask());
    // await new Promise(resolve => setTimeout(resolve, 20)); // Stagger connections slightly
  }

  await Promise.allSettled(devicePromises); // Wait for all devices to finish or fail

  const testEndTime = performance.now();
  stopMonitoring(); // Stop before calculations

  // --- Calculate Metrics ---
  const totalDurationSec = (testEndTime - testStartTime) / 1000;
  const totalMessagesSent = numMessages * argv.devices; // Ideal total

  // Latency (using collected publish latencies)
  const latencyStats = calculateStats(publishLatencies);

  // Messages/s: Total messages confirmed sent / total test duration
  // Note: publishLatencies.length reflects successful publishes tracked
  const actualMessagesSent = latencyStats.count;
  const avgMsgPerSec = actualMessagesSent / totalDurationSec || 0;

  // CPU/Memory Avg
  const avgCpu =
    cpuUsage.length > 0
      ? cpuUsage.reduce((a, b) => a + b, 0) / cpuUsage.length
      : 0;
  const avgMem =
    memoryUsage.length > 0
      ? memoryUsage.reduce((a, b) => a + b, 0) / memoryUsage.length
      : 0;

  // Output results for this message count
  console.log(
    `| ${String(numMessages).padEnd(10)} | ${latencyStats.avg
      .toFixed(2)
      .padEnd(15)} | ${avgMsgPerSec.toFixed(2).padEnd(15)} | ${avgCpu
      .toFixed(2)
      .padEnd(12)} | ${avgMem.toFixed(2).padEnd(15)} |`
  );

  // Optional: Add a delay between tests
  await new Promise((resolve) => setTimeout(resolve, 2000));
}

async function runAllTests() {
  console.log("--- MQTT Scalability Test (Message Count) ---");
  console.log(`Broker: ${argv.broker}:${argv.port}`);
  console.log(`Simulating ${argv.devices} devices.`);
  console.log(`Target PID: ${targetPid}`);
  console.log("-" * 70);
  console.log(
    "| {:<10} | {:<15} | {:<15} | {:<12} | {:<15} |"
      .replace(/{:<(\d+)}/g, (match, width) => "".padEnd(parseInt(width)))
      .replace(/\|/g, "|")
      .replace(/\[:\^(\d+)\]/g, (match, width) => "".padEnd(parseInt(width)))
      .format(
        "Messages",
        "Latency avg(ms)",
        "Messages/s avg",
        "CPU avg (%)",
        "Memory avg (MB)"
      )
  ); // Basic table header formatting
  console.log(
    "|------------|-----------------|-----------------|--------------|-----------------|"
  );

  for (const count of MESSAGE_COUNTS) {
    await runTestForMessageCount(count);
  }

  console.log("-" * 70);
  console.log("All tests complete.");
  // Ensure the main process exits cleanly if needed, especially if intervals aren't cleared properly
  process.exit(0);
}

// --- Execute ---
runAllTests().catch((err) => {
  console.error("Test suite failed:", err);
  process.exit(1);
});

// Optional: Handle Ctrl+C for graceful shutdown
process.on("SIGINT", () => {
  console.log("\nCaught interrupt signal. Shutting down...");
  stopMonitoring();
  // Add any other cleanup needed for clients etc.
  process.exit(0);
});

// Helper for basic string formatting (like Python's .format)
String.prototype.format = function (...args) {
  let i = 0;
  return this.replace(/{.*?}/g, (match) =>
    typeof args[i] !== "undefined" ? args[i++] : match
  );
};
