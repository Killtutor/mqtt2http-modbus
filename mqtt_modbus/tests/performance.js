/**
 * Performance Testing Script for MQTT-HTTP and MQTT-Modbus
 *
 * This script tests the performance of the MQTT to HTTP bridge and Modbus modules
 * Metrics measured:
 * - Latency (ms)
 * - Throughput (messages/s)
 * - CPU Usage (%)
 * - Memory Usage (MB)
 */

"use strict";

const mqtt = require("mqtt");
const fs = require("fs");
const path = require("path");
const { performance } = require("perf_hooks");
const pidusage = require("pidusage");
const config = require("./config.json");

// Test configuration
const TEST_DURATION = 60000; // 1 minute in ms
const MESSAGE_INTERVAL = 100; // ms between messages
const NUM_MESSAGES = Math.floor(TEST_DURATION / MESSAGE_INTERVAL);
const SAMPLE_INTERVAL = 1000; // 1 second sampling interval for CPU/mem
const TEST_MODULES = ["http", "modbus"];

// Results storage
const results = {
  http: {
    latencies: [],
    throughput: [],
    cpuUsage: [],
    memoryUsage: []
  },
  modbus: {
    latencies: [],
    throughput: [],
    cpuUsage: [],
    memoryUsage: []
  }
};

// Connect to MQTT broker
const client = mqtt.connect(
  `mqtt://${process.env.MQTT_HOST || config.mqttHost}:${
    process.env.MQTT_PORT || config.mqttPort
  }`,
  {
    password: process.env.MQTT_PASS || config.mqttPass,
    username: process.env.MQTT_USER || config.mqttUser
  }
);

// Mock HTTP server to capture requests from the HTTP module
const express = require("express");
const app = express();
const PORT = 8081;
let httpLatencies = [];

app.get("/httpds", (req, res) => {
  const messageId = req.query.messageId;
  if (messageId) {
    const endTime = performance.now();
    const startTime = parseInt(messageId.split("_")[1], 10);
    httpLatencies.push(endTime - startTime);
  }
  res.status(200).send("OK");
});

// Performance monitoring function
async function monitorPerformance(pid, moduleType) {
  try {
    const stats = await pidusage(pid);
    results[moduleType].cpuUsage.push(stats.cpu);
    results[moduleType].memoryUsage.push(stats.memory / 1024 / 1024); // Convert to MB
    return stats;
  } catch (error) {
    console.error(`Error monitoring ${moduleType} performance:`, error);
    return null;
  }
}

// Test the HTTP module
async function testHttpModule(httpPid) {
  console.log("Starting HTTP module performance test...");

  // Start performance monitoring
  const monitoringInterval = setInterval(async () => {
    await monitorPerformance(httpPid, "http");
  }, SAMPLE_INTERVAL);

  let messageCount = 0;
  let startTime = performance.now();

  // Send test messages
  const messageInterval = setInterval(() => {
    const timestamp = performance.now();
    client.publish(
      "testSite/parameter",
      JSON.stringify({
        value: Math.random() * 100,
        messageId: `http_${timestamp}`
      })
    );

    messageCount++;

    if (messageCount >= NUM_MESSAGES) {
      clearInterval(messageInterval);
      // Calculate throughput samples
      const endTime = performance.now();
      results.http.throughput.push(
        messageCount / ((endTime - startTime) / 1000)
      );

      // Save the latency results
      results.http.latencies = httpLatencies;

      clearInterval(monitoringInterval);
      console.log("HTTP module performance test completed.");
    }
  }, MESSAGE_INTERVAL);

  // Wait for test to complete
  return new Promise((resolve) => setTimeout(resolve, TEST_DURATION + 5000));
}

// Test the Modbus module
async function testModbusModule(modbusPid) {
  console.log("Starting Modbus module performance test...");

  // Start performance monitoring
  const monitoringInterval = setInterval(async () => {
    await monitorPerformance(modbusPid, "modbus");
  }, SAMPLE_INTERVAL);

  let messageCount = 0;
  let startTime = performance.now();
  const modbusLatencies = [];

  // Set up a Modbus client to test receiving data
  const ModbusRTU = require("modbus-serial");
  const client = new ModbusRTU();

  // Find the first sede in config
  const firstSede = config.modbusSedes[0];

  // Connect to the Modbus server
  try {
    await client.connectTCP("localhost", firstSede.port);
    client.setID(1);
  } catch (err) {
    console.error("Error connecting to Modbus server:", err);
  }

  // Send test messages
  const messageInterval = setInterval(async () => {
    const timestamp = performance.now();

    // Publish a message to Modbus topic
    mqtt.publish(
      `${firstSede.nombre}/1/holding/100`,
      String(Math.random() * 100)
    );

    // Attempt to read the value via Modbus
    try {
      const startReadTime = performance.now();
      await client.readHoldingRegisters(100, 1);
      const endReadTime = performance.now();
      modbusLatencies.push(endReadTime - startReadTime);
    } catch (err) {
      console.error("Error reading from Modbus:", err);
    }

    messageCount++;

    if (messageCount >= NUM_MESSAGES) {
      clearInterval(messageInterval);

      // Calculate throughput samples
      const endTime = performance.now();
      results.modbus.throughput.push(
        messageCount / ((endTime - startTime) / 1000)
      );

      // Save the latency results
      results.modbus.latencies = modbusLatencies;

      clearInterval(monitoringInterval);
      console.log("Modbus module performance test completed.");
    }
  }, MESSAGE_INTERVAL);

  // Wait for test to complete
  return new Promise((resolve) => setTimeout(resolve, TEST_DURATION + 5000));
}

// Calculate statistics for each metric
function calculateStats(array) {
  if (array.length === 0) return { avg: 0, min: 0, max: 0, stdDev: 0 };

  const sum = array.reduce((a, b) => a + b, 0);
  const avg = sum / array.length;
  const min = Math.min(...array);
  const max = Math.max(...array);

  const squareDiffs = array.map((value) => {
    const diff = value - avg;
    return diff * diff;
  });

  const avgSquareDiff =
    squareDiffs.reduce((a, b) => a + b, 0) / squareDiffs.length;
  const stdDev = Math.sqrt(avgSquareDiff);

  return { avg, min, max, stdDev };
}

// Generate the final report
function generateReport() {
  const report = {};

  for (const module of TEST_MODULES) {
    report[module] = {
      latency: calculateStats(results[module].latencies),
      throughput: calculateStats(results[module].throughput),
      cpuUsage: calculateStats(results[module].cpuUsage),
      memoryUsage: calculateStats(results[module].memoryUsage)
    };
  }

  // Format report as table
  console.log("Performance Test Results:");
  console.log("==========================");

  for (const module of TEST_MODULES) {
    console.log(`\n${module.toUpperCase()} Module:`);
    console.log(
      "----------------------------------------------------------------------------------"
    );
    console.log(
      "| Métrica              | Promedio      | Mínimo        | Máximo        | Desviación estándar |"
    );
    console.log(
      "|----------------------|---------------|---------------|---------------|----------------------|"
    );
    console.log(
      `| Latencia (ms)        | ${report[module].latency.avg
        .toFixed(2)
        .padEnd(13)} | ${report[module].latency.min
        .toFixed(2)
        .padEnd(13)} | ${report[module].latency.max
        .toFixed(2)
        .padEnd(13)} | ${report[module].latency.stdDev.toFixed(2).padEnd(20)} |`
    );
    console.log(
      `| Rendimiento (msgs/s) | ${report[module].throughput.avg
        .toFixed(2)
        .padEnd(13)} | ${report[module].throughput.min
        .toFixed(2)
        .padEnd(13)} | ${report[module].throughput.max
        .toFixed(2)
        .padEnd(13)} | ${report[module].throughput.stdDev
        .toFixed(2)
        .padEnd(20)} |`
    );
    console.log(
      `| Uso de CPU (%)       | ${report[module].cpuUsage.avg
        .toFixed(2)
        .padEnd(13)} | ${report[module].cpuUsage.min
        .toFixed(2)
        .padEnd(13)} | ${report[module].cpuUsage.max
        .toFixed(2)
        .padEnd(13)} | ${report[module].cpuUsage.stdDev
        .toFixed(2)
        .padEnd(20)} |`
    );
    console.log(
      `| Uso de memoria (MB)  | ${report[module].memoryUsage.avg
        .toFixed(2)
        .padEnd(13)} | ${report[module].memoryUsage.min
        .toFixed(2)
        .padEnd(13)} | ${report[module].memoryUsage.max
        .toFixed(2)
        .padEnd(13)} | ${report[module].memoryUsage.stdDev
        .toFixed(2)
        .padEnd(20)} |`
    );
    console.log(
      "----------------------------------------------------------------------------------"
    );
  }

  // Save results to JSON file
  fs.writeFileSync(
    path.join(__dirname, "performance_results.json"),
    JSON.stringify(report, null, 2)
  );
  console.log("\nDetailed results saved to performance_results.json");
}

// Main function to run the performance tests
async function runPerformanceTests(httpPid, modbusPid) {
  // Run HTTP module test
  await testHttpModule(httpPid);

  // Run Modbus module test
  await testModbusModule(modbusPid);

  // Generate report
  generateReport();

  // Close test server and MQTT client
  server.close();
  client.end();

  console.log("Performance tests completed.");
}

// Execute the performance tests if this script is run directly
if (require.main === module) {
  const args = process.argv.slice(2);
  const httpPid = parseInt(args[0], 10);
  const modbusPid = parseInt(args[1], 10);

  if (!httpPid || !modbusPid) {
    console.error("Usage: node performance.js <httpPid> <modbusPid>");
    process.exit(1);
  }

  runPerformanceTests(httpPid, modbusPid).catch((err) => {
    console.error("Error running performance tests:", err);
    process.exit(1);
  });
}

module.exports = {
  runPerformanceTests
};
