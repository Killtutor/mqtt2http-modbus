/**
 * Scalability Testing Script for MQTT-HTTP and MQTT-Modbus
 *
 * This script tests the scalability of the MQTT to HTTP bridge and Modbus modules
 * with increasing device loads: 5, 20, 100, 1000
 *
 * Metrics measured per device count:
 * - Average Latency (ms)
 * - Average messages/s
 * - Average CPU Usage (%)
 * - Average Memory Usage (MB)
 */

"use strict";

const mqtt = require("mqtt");
const fs = require("fs");
const path = require("path");
const { performance } = require("perf_hooks");
const pidusage = require("pidusage");
const config = require("./config.json");

// Test configuration
const TEST_DURATION = 120000; // 2 minutes per device count test
const MESSAGE_INTERVAL = 10; // ms between messages
const DEVICE_COUNTS = [5, 20, 100, 1000]; // Number of simulated devices
const MESSAGE_CORRECTION = { 5: 1, 20: 2, 100: 10, 1000: 100 }; // Correction factor for messages
const SAMPLE_INTERVAL = 1000; // 1 second sampling interval for CPU/mem
const TEST_MODULES = ["http", "modbus"];

// Results storage
const results = {
  http: {
    deviceStats: {}
  },
  modbus: {
    deviceStats: {}
  }
};

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

let httpLatencies = [];

// Performance monitoring function
async function monitorPerformance(pid, moduleType) {
  try {
    const stats = await pidusage(pid);
    return {
      cpu: stats.cpu,
      memory: stats.memory / 1024 / 1024 // Convert to MB
    };
  } catch (error) {
    console.error(`Error monitoring ${moduleType} performance:`, error);
    return { cpu: 0, memory: 0 };
  }
}

// Simulates multiple devices sending data through the HTTP module
async function testHttpModuleWithDevices(httpPid, deviceCount) {
  console.log(
    `Starting HTTP module scalability test with ${deviceCount} devices...`
  );

  // Reset latencies for this test
  httpLatencies = [];

  // Create clients for each simulated device
  const clients = Array(deviceCount)
    .fill(0)
    .map(() => createMqttClient());

  // Collect CPU and memory samples
  const cpuSamples = [];
  const memorySamples = [];

  const monitoringInterval = setInterval(async () => {
    const stats = await monitorPerformance(httpPid, "http");
    cpuSamples.push(stats.cpu);
    memorySamples.push(stats.memory);
  }, SAMPLE_INTERVAL);

  // Start time for throughput calculation
  const startTime = performance.now();
  let messageCount = 0;

  // Send messages from each device
  const devicePromises = clients.map((client) => {
    return new Promise((resolve) => {
      let deviceMessageCount = 0;
      const maxMessagesPerDevice = Math.floor(
        (TEST_DURATION / MESSAGE_INTERVAL / deviceCount) *
          MESSAGE_CORRECTION[deviceCount]
      );

      const interval = setInterval(() => {
        const timeStart = performance.now();
        client.publish(
          `PDVSA_SEDE1_http/string1`,
          JSON.stringify({
            humedad: Math.random(),
            presion: Math.random() * 1000,
            temp: Math.random() * 100
          })
        );
        const timeEnd = performance.now();
        httpLatencies.push(timeEnd - timeStart);

        deviceMessageCount++;
        messageCount++;

        if (deviceMessageCount >= maxMessagesPerDevice) {
          clearInterval(interval);
          client.end();
          resolve();
        }
      }, MESSAGE_INTERVAL * deviceCount);
    });
  });

  // Wait for all devices to finish
  await Promise.all(devicePromises);
  const endTime = performance.now();

  // Calculate throughput (messages per second)
  const throughput = messageCount / ((endTime - startTime) / 1000);

  // Calculate average latency
  const avgLatency =
    httpLatencies.length > 0
      ? httpLatencies.reduce((a, b) => a + b, 0) / httpLatencies.length
      : 0;

  // Calculate average CPU and memory usage
  const avgCpu =
    cpuSamples.length > 0
      ? cpuSamples.reduce((a, b) => a + b, 0) / cpuSamples.length
      : 0;
  const avgMemory =
    memorySamples.length > 0
      ? memorySamples.reduce((a, b) => a + b, 0) / memorySamples.length
      : 0;

  // Save results
  results.http.deviceStats[deviceCount] = {
    latency: avgLatency,
    throughput,
    cpuUsage: avgCpu,
    memoryUsage: avgMemory
  };

  // Clean up
  clearInterval(monitoringInterval);
  console.log(
    `HTTP module scalability test with ${deviceCount} devices completed.`
  );
}

// Simulates multiple devices sending data through the Modbus module
async function testModbusModuleWithDevices(modbusPid, deviceCount) {
  console.log(
    `Starting Modbus module scalability test with ${deviceCount} devices...`
  );

  // Create clients for each simulated device
  const clients = Array(deviceCount)
    .fill(0)
    .map(() => createMqttClient());

  // Find the first sede in config
  const firstSede = config.modbusSedes[0];

  // Collect CPU and memory samples
  const cpuSamples = [];
  const memorySamples = [];
  const latencies = [];

  const monitoringInterval = setInterval(async () => {
    const stats = await monitorPerformance(modbusPid, "modbus");
    cpuSamples.push(stats.cpu);
    memorySamples.push(stats.memory);
  }, SAMPLE_INTERVAL);

  // Start time for throughput calculation
  const startTime = performance.now();
  let messageCount = 0;

  // Send messages from each device
  const devicePromises = clients.map((client, deviceIndex) => {
    return new Promise((resolve) => {
      let deviceMessageCount = 0;
      const maxMessagesPerDevice = Math.floor(
        (TEST_DURATION / MESSAGE_INTERVAL / deviceCount) *
          MESSAGE_CORRECTION[deviceCount]
      );

      const interval = setInterval(async () => {
        // Publish a message to Modbus topic for this device
        const startReadTime = performance.now();
        try {
          client.publish(
            `${firstSede.nombre}/1/string/8`,
            `Probando PERFORMANCE ${deviceIndex}, en HTTP y MODBUS                                              `
          );
        } catch (error) {
          console.error("Error publishing message Modbus:", error);
        }
        const endReadTime = performance.now();
        latencies.push(endReadTime - startReadTime);

        deviceMessageCount++;
        messageCount++;

        if (deviceMessageCount >= maxMessagesPerDevice) {
          clearInterval(interval);
          client.end();
          resolve();
        }
      }, MESSAGE_INTERVAL * deviceCount);
    });
  });

  // Wait for all devices to finish
  await Promise.all(devicePromises);
  const endTime = performance.now();

  // Calculate throughput (messages per second)
  const throughput = messageCount / ((endTime - startTime) / 1000);

  // Calculate average latency
  const avgLatency =
    latencies.length > 0
      ? latencies.reduce((a, b) => a + b, 0) / latencies.length
      : 0;

  // Calculate average CPU and memory usage
  const avgCpu =
    cpuSamples.length > 0
      ? cpuSamples.reduce((a, b) => a + b, 0) / cpuSamples.length
      : 0;
  const avgMemory =
    memorySamples.length > 0
      ? memorySamples.reduce((a, b) => a + b, 0) / memorySamples.length
      : 0;

  // Save results
  results.modbus.deviceStats[deviceCount] = {
    latency: avgLatency,
    throughput,
    cpuUsage: avgCpu,
    memoryUsage: avgMemory
  };

  // Clean up
  clearInterval(monitoringInterval);
  console.log(
    `Modbus module scalability test with ${deviceCount} devices completed.`
  );
}

// Generate report with scalability results
function generateScalabilityReport() {
  console.log("Scalability Test Results:");
  console.log("=========================");

  for (const module of TEST_MODULES) {
    console.log(`\n${module.toUpperCase()} Module Scalability:`);
    console.log(
      "---------------------------------------------------------------------------------"
    );
    console.log(
      "| Dispositivos | Latencia avg(ms) | mensajes/s avg | CPU avg (%) | memoria avg (MB) |"
    );
    console.log(
      "|--------------|------------------|----------------|-------------|------------------|"
    );

    for (const deviceCount of DEVICE_COUNTS) {
      const stats = results[module].deviceStats[deviceCount] || {
        latency: 0,
        throughput: 0,
        cpuUsage: 0,
        memoryUsage: 0
      };
      console.log(
        `| ${String(deviceCount).padEnd(12)} | ${stats.latency
          .toFixed(2)
          .padEnd(16)} | ${stats.throughput
          .toFixed(2)
          .padEnd(14)} | ${stats.cpuUsage
          .toFixed(2)
          .padEnd(11)} | ${stats.memoryUsage.toFixed(2).padEnd(16)} |`
      );
    }

    console.log(
      "---------------------------------------------------------------------------------"
    );
  }

  // Save results to JSON file
  fs.writeFileSync(
    path.join(__dirname, "scalability_results.json"),
    JSON.stringify(results, null, 2)
  );
  console.log("\nDetailed results saved to scalability_results.json");
}

// Main function to run the scalability tests
async function runScalabilityTests(httpPid, modbusPid) {
  // Test each module with different device counts
  for (const module of TEST_MODULES) {
    for (const deviceCount of DEVICE_COUNTS) {
      if (module === "http") {
        await testHttpModuleWithDevices(httpPid, deviceCount);
      } else if (module === "modbus") {
        await testModbusModuleWithDevices(modbusPid, deviceCount);
      }
    }
  }

  // Generate the final report
  generateScalabilityReport();

  console.log("Scalability tests completed.");
}

// Execute the scalability tests if this script is run directly
if (require.main === module) {
  const args = process.argv.slice(2);
  const httpPid = parseInt(args[0], 10);
  const modbusPid = parseInt(args[1], 10);

  if (!httpPid || !modbusPid) {
    console.error("Usage: node scalability.js <httpPid> <modbusPid>");
    process.exit(1);
  }
  runScalabilityTests(httpPid, modbusPid).catch((err) => {
    console.error("Error running scalability tests:", err);
    process.exit(1);
  });
}

module.exports = {
  runScalabilityTests
};
