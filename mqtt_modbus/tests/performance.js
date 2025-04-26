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
const SAMPLE_INTERVAL = 1000; // 1 second sampling interval for CPU/mem
const TEST_MODULES = ["http", "modbus"];
const PARALLEL_CLIENTS = 1; // Number of parallel MQTT clients to use
const BATCH_SIZE = 50; // Number of messages to send in a batch
const THROTTLE_DELAY = 10; // ms to wait between batches
const QOS_LEVEL = 1; // QoS level for MQTT messages
const MESSAGE_VERIFICATION_TIMEOUT = 30000; // 30 seconds timeout for message processing verification

// Topics for stats
const HTTP_STATS_REQUEST_TOPIC = "http_module/stats/request";
const HTTP_STATS_RESPONSE_TOPIC = "http_module/stats/response";
const HTTP_STATS_RESET_TOPIC = "http_module/stats/reset";
const MODBUS_STATS_REQUEST_TOPIC = "modbus_module/stats/request";
const MODBUS_STATS_RESPONSE_TOPIC = "modbus_module/stats/response";
const MODBUS_STATS_RESET_TOPIC = "modbus_module/stats/reset";

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

// Stats MQTT client
let statsMqttClient = null;

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

// Setup the stats MQTT client
async function setupStatsMqttClient() {
  if (statsMqttClient) {
    await new Promise((resolve) => {
      statsMqttClient.end(true, {}, resolve);
    });
  }

  const clientId = `stats-requester-${Date.now()}`;
  const clientOptions = {
    clientId,
    username: process.env.MQTT_USER || config.mqttUser,
    password: process.env.MQTT_PASS || config.mqttPass
  };

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

// Get processed message count via MQTT
async function getProcessedMessageCount(isHttp) {
  return new Promise((resolve, reject) => {
    const requestTopic = isHttp
      ? HTTP_STATS_REQUEST_TOPIC
      : MODBUS_STATS_REQUEST_TOPIC;
    const responseTopic = isHttp
      ? HTTP_STATS_RESPONSE_TOPIC
      : MODBUS_STATS_RESPONSE_TOPIC;

    // Set timeout
    const timeout = setTimeout(() => {
      statsMqttClient.removeListener("message", messageHandler);
      console.warn(
        `Timeout (${
          MESSAGE_VERIFICATION_TIMEOUT / 1000
        }s) waiting for message count for ${isHttp ? "HTTP" : "Modbus"} module`
      );
      resolve(0);
    }, MESSAGE_VERIFICATION_TIMEOUT);

    // Set up response handler
    const messageHandler = (topic, message) => {
      if (topic === responseTopic) {
        clearTimeout(timeout);
        try {
          const data = JSON.parse(message.toString());
          statsMqttClient.removeListener("message", messageHandler);
          resolve(data.processedMessages || 0);
        } catch (e) {
          console.error(
            `Error parsing stats response from ${responseTopic}:`,
            e
          );
          statsMqttClient.removeListener("message", messageHandler);
          resolve(0);
        }
      }
    };

    // Add message handler
    statsMqttClient.on("message", messageHandler);

    // Send request
    statsMqttClient.publish(requestTopic, "");
  });
}

// Reset message counters via MQTT
async function resetMessageCounters(isHttp) {
  return new Promise((resolve) => {
    const resetTopic = isHttp
      ? HTTP_STATS_RESET_TOPIC
      : MODBUS_STATS_RESET_TOPIC;
    const responseTopic = isHttp
      ? HTTP_STATS_RESPONSE_TOPIC
      : MODBUS_STATS_RESPONSE_TOPIC;

    // Set timeout
    const timeout = setTimeout(() => {
      statsMqttClient.removeListener("message", messageHandler);
      console.warn(
        `Timeout (${
          MESSAGE_VERIFICATION_TIMEOUT / 1000
        }s) waiting for reset confirmation from ${
          isHttp ? "HTTP" : "Modbus"
        } module`
      );
      resolve();
    }, MESSAGE_VERIFICATION_TIMEOUT);

    // Set up response handler
    const messageHandler = (topic, message) => {
      if (topic === responseTopic) {
        try {
          const data = JSON.parse(message.toString());
          if (data.reset) {
            clearTimeout(timeout);
            statsMqttClient.removeListener("message", messageHandler);
            resolve();
          }
        } catch (e) {
          console.error(
            `Error parsing reset response from ${responseTopic}:`,
            e
          );
          clearTimeout(timeout);
          statsMqttClient.removeListener("message", messageHandler);
          resolve();
        }
      }
    };

    // Add message handler
    statsMqttClient.on("message", messageHandler);

    // Send request
    statsMqttClient.publish(resetTopic, "");
  });
}

// Wait for all messages to be processed
async function waitForMessageProcessing(totalSent, isHttp) {
  console.log(
    `Waiting for ${totalSent} messages to be processed by ${
      isHttp ? "HTTP" : "MODBUS"
    } module...`
  );

  const maxWaitTime = 60000; // 60 seconds max wait
  const startTime = performance.now();
  let processed = 0;
  let timeWaiting = 0;

  while (processed < totalSent && timeWaiting < maxWaitTime) {
    processed = await getProcessedMessageCount(isHttp);
    const percentComplete = Math.round((processed / totalSent) * 100);
    console.log(
      `Progress: ${processed}/${totalSent} messages processed (${percentComplete}%)`
    );

    if (processed >= totalSent) {
      console.log(`All ${totalSent} messages processed successfully!`);
      break;
    }

    // Wait before checking again
    await new Promise((resolve) => setTimeout(resolve, 2000));
    timeWaiting = performance.now() - startTime;
  }

  if (processed < totalSent) {
    console.warn(
      `Timeout waiting for message processing. Only ${processed}/${totalSent} processed (${Math.round(
        (processed / totalSent) * 100
      )}%).`
    );
  }

  return processed;
}

// Test the HTTP module
async function testHttpModule(httpPid) {
  console.log("Starting HTTP module performance test...");

  // Reset message counters before starting
  await resetMessageCounters(true);

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

    console.log(`Sent a total of ${messageCount} HTTP messages`);

    // Wait for all messages to be processed
    const processedCount = await waitForMessageProcessing(messageCount, true);

    // Calculate throughput based on actually processed messages
    const endTime = performance.now();
    const duration = (endTime - startTime) / 1000; // in seconds
    const actualThroughput = processedCount / duration;
    results.http.throughput.push(actualThroughput);

    console.log(
      `HTTP throughput: ${actualThroughput.toFixed(
        2
      )} msgs/s (${processedCount} messages in ${duration.toFixed(2)}s)`
    );

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

  // Reset message counters before starting
  await resetMessageCounters(false);

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

    console.log(`Sent a total of ${messageCount} MODBUS messages`);

    // Wait for all messages to be processed
    const processedCount = await waitForMessageProcessing(messageCount, false);

    // Calculate throughput based on actually processed messages
    const endTime = performance.now();
    const duration = (endTime - startTime) / 1000; // in seconds
    const actualThroughput = processedCount / duration;
    results.modbus.throughput.push(actualThroughput);

    console.log(
      `MODBUS throughput: ${actualThroughput.toFixed(
        2
      )} msgs/s (${processedCount} messages in ${duration.toFixed(2)}s)`
    );

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
  // Setup the stats MQTT client first
  await setupStatsMqttClient();

  // Run HTTP module test
  await testHttpModule(httpPid);

  // Wait a bit to let system stabilize
  console.log(
    "Waiting 30 seconds for system to stabilize before the next test..."
  );
  await new Promise((resolve) => setTimeout(resolve, 30000));

  // Run Modbus module test
  await testModbusModule(modbusPid);

  // Generate report
  generateReport();

  // Clean up
  if (statsMqttClient) {
    statsMqttClient.end();
  }

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
