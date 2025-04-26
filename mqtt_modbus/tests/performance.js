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
const SAMPLE_INTERVAL = 1000; // 1 second sampling interval for CPU/mem
const TEST_MODULES = ["http", "modbus"];
const PARALLEL_CLIENTS = 5; // Number of parallel MQTT clients to use
const BATCH_SIZE = 50; // Number of messages to send in a batch
const THROTTLE_DELAY = 10; // ms to wait between batches
const QOS_LEVEL = 1; // QoS level for MQTT messages

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

// Connect multiple MQTT clients
async function connectMqttClients(count, moduleType) {
  const clients = [];
  for (let i = 0; i < count; i++) {
    const clientId = `perf-test-${moduleType}-client-${i}-${Date.now()}`;
    const client = mqtt.connect(mqttConnection, {
      ...mqttCredentials,
      clientId
    });
    await new Promise((resolve, reject) => {
      client.on("connect", resolve);
      client.on("error", reject);
    });
    clients.push(client);
  }
  return clients;
}

// Test the HTTP module
async function testHttpModule(httpPid) {
  console.log("Starting HTTP module performance test...");
  let messageCount = 0;
  const httpLatencies = [];
  const startTime = performance.now();

  // Start performance monitoring
  const monitoringInterval = setInterval(async () => {
    await monitorPerformance(httpPid, "http");
  }, SAMPLE_INTERVAL);

  try {
    // Connect multiple clients
    const clients = await connectMqttClients(PARALLEL_CLIENTS, "http");

    // Calculate how many total messages each client should send
    const testEndTime = startTime + TEST_DURATION;

    // Run parallel publishing
    const clientPromises = clients.map(async (client, clientIndex) => {
      let clientMsgCount = 0;

      while (performance.now() < testEndTime) {
        // Send a batch of messages
        const batchPromises = [];
        for (let i = 0; i < BATCH_SIZE; i++) {
          const startReadTime = performance.now();
          try {
            const promise = new Promise((resolve) => {
              client.publish(
                `PDVSA_SEDE1_http/string${clientIndex + 1}`,
                JSON.stringify({
                  temp: 18 + Math.random() * 10,
                  presion: 2.5 + Math.random(),
                  humedad: 0.8 * Math.random(),
                  timestamp: Date.now()
                }),
                { qos: QOS_LEVEL },
                () => {
                  const endReadTime = performance.now();
                  httpLatencies.push(endReadTime - startReadTime);
                  resolve();
                }
              );
            });
            batchPromises.push(promise);
            clientMsgCount++;
          } catch (error) {
            console.error(
              `Client ${clientIndex} error publishing message:`,
              error
            );
          }
        }

        // Wait for all messages in batch to be published
        await Promise.all(batchPromises);

        // Add throttling between batches
        await new Promise((resolve) => setTimeout(resolve, THROTTLE_DELAY));

        // Log progress occasionally
        if (clientMsgCount % 1000 === 0) {
          console.log(
            `Client ${clientIndex}: ${clientMsgCount} HTTP messages sent`
          );
        }
      }

      return clientMsgCount;
    });

    // Wait for all clients to finish
    const clientCounts = await Promise.all(clientPromises);
    messageCount = clientCounts.reduce((a, b) => a + b, 0);

    // Calculate throughput
    const endTime = performance.now();
    const duration = (endTime - startTime) / 1000; // in seconds
    results.http.throughput.push(messageCount / duration);

    // Save latency results
    results.http.latencies = httpLatencies;

    // Clean up clients
    clients.forEach((client) => client.end());
  } catch (error) {
    console.error("Error in HTTP test:", error);
  } finally {
    clearInterval(monitoringInterval);
    console.log(
      `HTTP module test completed with ${messageCount} messages sent.`
    );
  }
}

// Test the Modbus module
async function testModbusModule(modbusPid) {
  console.log("Starting Modbus module performance test...");
  let messageCount = 0;
  const modbusLatencies = [];
  const startTime = performance.now();

  // Find the first sede in config
  const firstSede = config.modbusSedes[0];

  // Start performance monitoring
  const monitoringInterval = setInterval(async () => {
    await monitorPerformance(modbusPid, "modbus");
  }, SAMPLE_INTERVAL);

  try {
    // Connect multiple clients
    const clients = await connectMqttClients(PARALLEL_CLIENTS, "modbus");

    // Calculate end time
    const testEndTime = startTime + TEST_DURATION;

    // Run parallel publishing
    const clientPromises = clients.map(async (client, clientIndex) => {
      let clientMsgCount = 0;

      while (performance.now() < testEndTime) {
        // Send a batch of messages
        const batchPromises = [];
        for (let i = 0; i < BATCH_SIZE; i++) {
          const startReadTime = performance.now();
          try {
            // Generate a value within Modbus register range (-32768 to 32767)
            const value = Math.floor(Math.random() * 65535) - 32768;

            const promise = new Promise((resolve) => {
              client.publish(
                `${firstSede.nombre}/${clientIndex + 1}/holding/${i % 100}`,
                String(value),
                { qos: QOS_LEVEL },
                () => {
                  const endReadTime = performance.now();
                  modbusLatencies.push(endReadTime - startReadTime);
                  resolve();
                }
              );
            });
            batchPromises.push(promise);
            clientMsgCount++;
          } catch (error) {
            console.error(
              `Client ${clientIndex} error publishing message:`,
              error
            );
          }
        }

        // Wait for all messages in batch to be published
        await Promise.all(batchPromises);

        // Add throttling between batches
        await new Promise((resolve) => setTimeout(resolve, THROTTLE_DELAY));

        // Log progress occasionally
        if (clientMsgCount % 1000 === 0) {
          console.log(
            `Client ${clientIndex}: ${clientMsgCount} MODBUS messages sent`
          );
        }
      }

      return clientMsgCount;
    });

    // Wait for all clients to finish
    const clientCounts = await Promise.all(clientPromises);
    messageCount = clientCounts.reduce((a, b) => a + b, 0);

    // Calculate throughput
    const endTime = performance.now();
    const duration = (endTime - startTime) / 1000; // in seconds
    results.modbus.throughput.push(messageCount / duration);

    // Save latency results
    results.modbus.latencies = modbusLatencies;

    // Clean up clients
    clients.forEach((client) => client.end());
  } catch (error) {
    console.error("Error in MODBUS test:", error);
  } finally {
    clearInterval(monitoringInterval);
    console.log(
      `MODBUS module test completed with ${messageCount} messages sent.`
    );
  }
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

  // Wait a bit to let system stabilize
  await new Promise((resolve) => setTimeout(resolve, 30000));

  // Run Modbus module test
  await testModbusModule(modbusPid);

  // Wait for any pending messages to be processed
  await new Promise((resolve) => setTimeout(resolve, 60000));

  // Generate report
  generateReport();

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
