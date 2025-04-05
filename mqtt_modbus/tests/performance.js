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
const TEST_DURATION = 120000; // 2 minute in ms
const MESSAGE_INTERVAL = 1; // ms between messages
const NUM_MESSAGES = Math.floor(TEST_DURATION / MESSAGE_INTERVAL) * 10;
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
const mqttConnection = `mqtt://${process.env.MQTT_HOST || config.mqttHost}:${
  process.env.MQTT_PORT || config.mqttPort
}`;
console.log("🚀 ~ mqttConnection:", mqttConnection);
const mqttCredentials = {
  password: process.env.MQTT_PASS || config.mqttPass,
  username: process.env.MQTT_USER || config.mqttUser
};
console.log("🚀 ~ mqttCredentials:", mqttCredentials);
// Connect to MQTT broker
const client = mqtt.connect(mqttConnection, mqttCredentials);

let httpLatencies = [];

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
    const startReadTime = performance.now();
    try {
      client.publish(
        `PDVSA_SEDE1_http/string1`,
        JSON.stringify({
          temp: 18,
          presion: 2.5,
          humedad: 0.8
        })
      );
    } catch (error) {
      console.error("Error publishing message HTTP:", error);
    }
    const endReadTime = performance.now();
    httpLatencies.push(endReadTime - startReadTime);

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

  // Find the first sede in config
  const firstSede = config.modbusSedes[0];

  const messageInterval = setInterval(() => {
    const startReadTime = performance.now();
    try {
      client.publish(
        `${firstSede.nombre}/1/string/8`,
        "Probando PERFORMANCE, en HTTP y MODBUS                                              "
      );
    } catch (error) {
      console.error("Error publishing message Modbus:", error);
    }
    const endReadTime = performance.now();
    modbusLatencies.push(endReadTime - startReadTime);

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
