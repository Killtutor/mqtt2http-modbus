"use strict";

const mqtt = require("mqtt");
const { performance } = require("perf_hooks");
const pidusage = require("pidusage");
const config = require("./config.json");
const os = require("os"); // Required for CPU monitoring alternative
const fs = require("fs");
const path = require("path");

// --- Configuration ---
const MESSAGE_COUNTS = [100, 500, 2500, 5000];
// Find the first sede in config
const firstSede = config.modbusSedes[0];
const HTTP_TOPIC_TEMPLATE = "PDVSA_SEDE1_http/numero"; // Topic template for HTTP
const MODBUS_TOPIC_TEMPLATE = `${firstSede.nombre}/1/holding/0`; // Topic template for Modbus
const CLIENT_ID_TEMPLATE = "scalability-tester-mc-{device_id}-{timestamp}"; // Unique client ID
const DEFAULT_QOS = 1;
const MONITOR_INTERVAL = 1000; // ms for CPU/Mem sampling

// Topics for stats
const HTTP_STATS_REQUEST_TOPIC = "http_module/stats/request";
const HTTP_STATS_RESPONSE_TOPIC = "http_module/stats/response";
const HTTP_STATS_RESET_TOPIC = "http_module/stats/reset";
const MODBUS_STATS_REQUEST_TOPIC = "modbus_module/stats/request";
const MODBUS_STATS_RESPONSE_TOPIC = "modbus_module/stats/response";
const MODBUS_STATS_RESET_TOPIC = "modbus_module/stats/reset";

// --- Globals ---
let publishLatencies = []; // Array to store publish latencies for calculation
let cpuUsage = [];
let memoryUsage = [];
let monitoringIntervalId = null;
let targetPid = null; // PID of the process being monitored
let testResults = []; // To store results for file output
let currentTestType = ""; // To track whether we're testing HTTP or MODBUS
let statsMqttClient = null; // MQTT client for stats requests

// --- File Output ---
const timestamp = new Date()
  .toISOString()
  .replace(/:/g, "-")
  .replace(/\..+/, "");
const resultsDir = path.join(__dirname, "results");
const resultsFilename = `message_count_results_${timestamp}.csv`;
const resultsPath = path.join(resultsDir, resultsFilename);

// Ensure results directory exists
function setupResultsDirectory() {
  if (!fs.existsSync(resultsDir)) {
    fs.mkdirSync(resultsDir, { recursive: true });
  }
  // Create CSV header
  const header =
    "Interface,Messages,Latency_avg_ms,Messages_per_sec,CPU_avg_percent,Memory_avg_MB,Processed_Messages\n";
  fs.writeFileSync(resultsPath, header);
  console.info(`Results will be saved to: ${resultsPath}`);
}

// Function to save a single test result
function saveTestResult(
  messageCount,
  latencyAvg,
  messagesPerSec,
  cpuAvg,
  memAvg,
  processedCount
) {
  const resultLine = `${currentTestType},${messageCount},${latencyAvg.toFixed(
    2
  )},${messagesPerSec.toFixed(2)},${cpuAvg.toFixed(2)},${memAvg.toFixed(
    2
  )},${processedCount}\n`;
  fs.appendFileSync(resultsPath, resultLine);
}

// --- Helper Functions ---
function connectMqtt(clientIdSuffix) {
  const uniqueClientId = CLIENT_ID_TEMPLATE.replace(
    "{device_id}",
    clientIdSuffix
  ).replace("{timestamp}", Date.now());

  const clientOptions = {
    clientId: uniqueClientId,
    username: process.env.MQTT_USER || config.mqttUser,
    password: process.env.MQTT_PASS || config.mqttPass
  };

  const mqttConnection = `mqtt://${process.env.MQTT_HOST || config.mqttHost}:${
    process.env.MQTT_PORT || config.mqttPort
  }`;

  return new Promise((resolve, reject) => {
    const client = mqtt.connect(mqttConnection, clientOptions);
    client.on("connect", () => {
      resolve(client);
    });
    client.on("error", (err) => {
      console.error(`${uniqueClientId}: Connection error:`, err);
      client.end(); // Clean up
      reject(err);
    });
    client.on("offline", () => {
      console.warn(`${uniqueClientId}: Client went offline.`);
    });
    client.on("reconnect", () => {
      console.warn(`${uniqueClientId}: Reconnecting...`);
    });
  });
}

// Connect dedicated MQTT client for stats
async function setupStatsMqttClient() {
  if (statsMqttClient) {
    await new Promise((resolve) => {
      statsMqttClient.end(true, {}, resolve);
    });
  }

  const clientId = `stats-requester`;
  const clientOptions = {
    clientId,
    username: process.env.MQTT_USER || config.mqttUser,
    password: process.env.MQTT_PASS || config.mqttPass
  };

  const mqttConnection = `mqtt://${process.env.MQTT_HOST || config.mqttHost}:${
    process.env.MQTT_PORT || config.mqttPort
  }`;

  return new Promise((resolve, reject) => {
    statsMqttClient = mqtt.connect(mqttConnection, clientOptions);

    statsMqttClient.on("connect", () => {
      // Subscribe to stats response topics
      statsMqttClient.subscribe(HTTP_STATS_RESPONSE_TOPIC);
      statsMqttClient.subscribe(MODBUS_STATS_RESPONSE_TOPIC);
      console.info(`Stats MQTT client connected with ID: ${clientId}`);
      resolve(statsMqttClient);
    });

    statsMqttClient.on("error", (err) => {
      console.error(`Stats MQTT client error:`, err);
      reject(err);
    });
  });
}

async function publishMessages(client, deviceId, topic, numMessages) {
  const clientIdentifier = client.options.clientId; // Get the unique client ID
  const localLatencies = [];
  const basePayload = { value: Math.random() * 2000 - 1000, ts: 0 }; // Random numeric value

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
    } catch (error) {
      break; // Stop publishing for this client on error
    }
  }
}

async function monitorPerformance(pid) {
  if (!pid) return;

  try {
    const stats = await pidusage(pid);
    cpuUsage.push(stats.cpu);
    memoryUsage.push(stats.memory / 1024 / 1024); // Convert to MB
  } catch (error) {
    // Handle cases where PID doesn't exist anymore
    if (error.message.includes("No matching pid found")) {
      if (monitoringIntervalId) clearInterval(monitoringIntervalId);
      monitoringIntervalId = null;
    } else {
      console.error(`Error monitoring PID ${pid}:`, error);
    }
  }
}

function startMonitoring(pid) {
  if (monitoringIntervalId) clearInterval(monitoringIntervalId);
  cpuUsage = [];
  memoryUsage = [];
  // Run once immediately to start collecting data
  monitorPerformance(pid);
  monitoringIntervalId = setInterval(
    () => monitorPerformance(pid),
    MONITOR_INTERVAL
  );
}

function stopMonitoring(pid) {
  if (monitoringIntervalId) {
    clearInterval(monitoringIntervalId);
    monitoringIntervalId = null;
    // Run one final time to capture final state
    return monitorPerformance(pid);
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

// --- Get Processed Message Count via MQTT ---
async function getProcessedMessageCount(isHttp) {
  return new Promise((resolve, reject) => {
    const requestTopic = isHttp
      ? HTTP_STATS_REQUEST_TOPIC
      : MODBUS_STATS_REQUEST_TOPIC;
    const responseTopic = isHttp
      ? HTTP_STATS_RESPONSE_TOPIC
      : MODBUS_STATS_RESPONSE_TOPIC;

    // Set up response handler
    const messageHandler = (topic, message) => {
      if (topic === responseTopic) {
        try {
          const data = JSON.parse(message.toString());
          statsMqttClient.removeListener("message", messageHandler);
          resolve(data.processedMessages || 0);
        } catch (e) {
          console.error("Error parsing stats response:", e);
          resolve(0);
        }
      }
    };

    // Add message handler
    statsMqttClient.on("message", messageHandler);

    // Send request
    statsMqttClient.publish(requestTopic, "");

    // Set timeout
    setTimeout(() => {
      statsMqttClient.removeListener("message", messageHandler);
      console.warn(
        `Timeout getting message count for ${isHttp ? "HTTP" : "Modbus"}`
      );
      resolve(0);
    }, 50000);
  });
}

// --- Reset Message Counters via MQTT ---
async function resetMessageCounters(isHttp) {
  return new Promise((resolve) => {
    const resetTopic = isHttp
      ? HTTP_STATS_RESET_TOPIC
      : MODBUS_STATS_RESET_TOPIC;
    const responseTopic = isHttp
      ? HTTP_STATS_RESPONSE_TOPIC
      : MODBUS_STATS_RESPONSE_TOPIC;

    // Set up response handler
    const messageHandler = (topic, message) => {
      if (topic === responseTopic) {
        try {
          const data = JSON.parse(message.toString());
          if (data.reset) {
            statsMqttClient.removeListener("message", messageHandler);
            console.info(
              `Reset message counter for ${isHttp ? "HTTP" : "MODBUS"}`
            );
            resolve();
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
    };

    // Add message handler
    statsMqttClient.on("message", messageHandler);

    // Send request
    statsMqttClient.publish(resetTopic, "");

    // Set timeout
    setTimeout(() => {
      statsMqttClient.removeListener("message", messageHandler);
      console.warn(
        `Timeout resetting message count for ${isHttp ? "HTTP" : "Modbus"}`
      );
      resolve();
    }, 50000);
  });
}

// --- Main Test Logic ---
async function runTestForMessageCount(numMessages, devices, pid, http) {
  // Reset message counters before starting the test
  await resetMessageCounters(http);

  publishLatencies = []; // Reset latencies for this run

  startMonitoring(pid);
  const testStartTime = performance.now();
  const devicePromises = [];

  // Select the appropriate topic template based on interface type
  const topicTemplate = http ? HTTP_TOPIC_TEMPLATE : MODBUS_TOPIC_TEMPLATE;

  for (let i = 0; i < devices; i++) {
    const deviceId = `device-${i}`;
    const topic = topicTemplate;

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
  }

  await Promise.allSettled(devicePromises); // Wait for all devices to finish or fail

  const testEndTime = performance.now();
  await stopMonitoring(pid); // Stop monitoring before calculations

  // --- Give some time for messages to be processed ---
  await new Promise((resolve) => setTimeout(resolve, 5000));

  // --- Get the processed message count ---
  const processedCount = await getProcessedMessageCount(http);

  // --- Calculate Metrics ---
  const totalDurationSec = (testEndTime - testStartTime) / 1000;

  // Latency (using collected publish latencies)
  const latencyStats = calculateStats(publishLatencies);
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
  console.info(
    `| ${String(numMessages).padEnd(10)} | ${latencyStats.avg
      .toFixed(2)
      .padEnd(15)} | ${avgMsgPerSec.toFixed(2).padEnd(15)} | ${avgCpu
      .toFixed(2)
      .padEnd(12)} | ${avgMem.toFixed(2).padEnd(15)} | ${processedCount
      .toString()
      .padEnd(10)} |`
  );

  // Save to file
  saveTestResult(
    numMessages,
    latencyStats.avg,
    avgMsgPerSec,
    avgCpu,
    avgMem,
    processedCount
  );

  // Add a delay between tests
  await new Promise((resolve) => setTimeout(resolve, 2000));
}

async function runAllTests(devices = 5, httpPid, modbusPid) {
  // Setup results directory and file
  setupResultsDirectory();

  // Setup MQTT client for stats
  await setupStatsMqttClient();

  // First run HTTP tests
  currentTestType = "HTTP";
  console.info("--- MQTT Scalability Test (Message Count - HTTP) ---");
  console.info(`Simulating ${devices} devices.`);
  console.info(`Target PID: ${httpPid} HTTP`);
  console.info(`Waiting 15 seconds before starting tests...`);

  // Add timeout before starting tests
  await new Promise((resolve) => setTimeout(resolve, 15000));

  console.info("-".repeat(90));
  console.info(
    "| Messages     | Latency avg(ms) | Messages/s avg | CPU avg (%) | Memory avg (MB) | Processed |"
  );
  console.info(
    "|------------|-----------------|-----------------|--------------|-----------------|-----------|"
  );

  for (const count of MESSAGE_COUNTS) {
    await runTestForMessageCount(count, devices, httpPid, true);
  }

  console.info("-".repeat(90));
  console.info("HTTP tests complete.");

  // Then run Modbus tests
  currentTestType = "MODBUS";
  console.info("\n--- MQTT Scalability Test (Message Count - MODBUS) ---");
  console.info(`Simulating ${devices} devices.`);
  console.info(`Target PID: ${modbusPid} MODBUS`);
  console.info(`Waiting 15 seconds before starting tests...`);

  // Add timeout before starting tests
  await new Promise((resolve) => setTimeout(resolve, 15000));

  console.info("-".repeat(90));
  console.info(
    "| Messages     | Latency avg(ms) | Messages/s avg | CPU avg (%) | Memory avg (MB) | Processed |"
  );
  console.info(
    "|------------|-----------------|-----------------|--------------|-----------------|-----------|"
  );

  for (const count of MESSAGE_COUNTS) {
    await runTestForMessageCount(count, devices, modbusPid, false);
  }

  console.info("-".repeat(90));
  console.info("All tests complete.");
  console.info(`Full results saved to: ${resultsPath}`);

  // Clean up MQTT client
  if (statsMqttClient) {
    statsMqttClient.end();
  }
}

// --- Execute ---
if (require.main === module) {
  const args = process.argv.slice(2);
  const httpPid = parseInt(args[0], 10);
  const modbusPid = parseInt(args[1], 10);

  if (!httpPid || !modbusPid) {
    console.error("Usage: node message_count.js <httpPid> <modbusPid>");
    process.exit(1);
  }

  // Run tests with 10 devices
  runAllTests(1, httpPid, modbusPid).catch((err) => {
    console.error("Test suite failed:", err);
    process.exit(1);
  });
}

// Export for use in other modules
module.exports = {
  runAllTests
};

// Handle Ctrl+C for graceful shutdown
process.on("SIGINT", () => {
  console.info("\nCaught interrupt signal. Shutting down...");
  if (monitoringIntervalId) clearInterval(monitoringIntervalId);
  if (statsMqttClient) statsMqttClient.end();
  process.exit(0);
});
