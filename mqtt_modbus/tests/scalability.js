/**
 * Scalability Testing Script for MQTT-HTTP and MQTT-Modbus
 *
 * This script tests the scalability of the MQTT to HTTP bridge and Modbus modules
 * with increasing device loads: 5, 20, 50, 100
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
const MESSAGES_PER_DEVICE = 15; // Total messages per device per test - FIXED COUNT
const SAMPLE_INTERVAL = 1000; // 1 second sampling interval for CPU/mem
const DEVICE_COUNTS = [5, 10, 25, 50, 75, 100]; // Number of simulated devices
const BATCH_SIZE = 3; // Send messages in small batches
const PROCESSING_CHECK_INTERVAL = 2500; // Check processing progress every 2.5 seconds
const QOS_LEVEL = 1; // QoS level for MQTT messages
const MESSAGE_VERIFICATION_TIMEOUT = 30000; // 30 seconds timeout for message processing verification
const TEST_MODULES = ["http", "modbus"];
const BACKLOG_CHECK_THRESHOLD = 5; // Check for backlog after this many batches

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
    deviceStats: {}
  },
  modbus: {
    deviceStats: {}
  }
};

// Stats MQTT client
let statsMqttClient = null;

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
    statsMqttClient = mqtt.connect(
      `mqtt://${process.env.MQTT_HOST || config.mqttHost}:${
        process.env.MQTT_PORT || config.mqttPort
      }`,
      clientOptions
    );

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

  const maxWaitTime = 120000; // 2 minutes max wait
  const startTime = performance.now();
  let processed = 0;
  let timeWaiting = 0;
  let lastProcessedCount = 0;
  let stagnantCount = 0;

  while (processed < totalSent && timeWaiting < maxWaitTime) {
    processed = await getProcessedMessageCount(isHttp);
    const percentComplete = Math.round((processed / totalSent) * 100);
    console.log(
      `Progress: ${processed}/${totalSent} messages processed (${percentComplete}%)`
    );

    // Check if processing is stagnant
    if (processed === lastProcessedCount) {
      stagnantCount++;
      if (stagnantCount >= 5) {
        console.warn(
          `Processing appears to be stalled. No progress for ${stagnantCount} checks.`
        );
        break;
      }
    } else {
      stagnantCount = 0;
      lastProcessedCount = processed;
    }

    if (processed >= totalSent) {
      console.log(`All ${totalSent} messages processed successfully!`);
      break;
    }

    // Wait before checking again
    await new Promise((resolve) =>
      setTimeout(resolve, PROCESSING_CHECK_INTERVAL)
    );
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

// Collect throughput sample for a specified time period
async function collectThroughputSample(
  moduleType,
  isHttp,
  startTime,
  lastMessageCount,
  deviceCount
) {
  const currentTime = performance.now();
  const elapsedSeconds = (currentTime - startTime) / 1000;

  // Get current processed message count
  const currentProcessed = await getProcessedMessageCount(isHttp);

  // Calculate throughput for this sample period
  const messageDelta = currentProcessed - lastMessageCount;
  const sampleDuration = 5; // Sample over approximately 5 seconds
  const throughput = messageDelta / sampleDuration;

  if (messageDelta > 0) {
    console.log(
      `[${moduleType.toUpperCase()}] [${deviceCount} devices] [${elapsedSeconds.toFixed(
        1
      )}s] Current throughput: ${throughput.toFixed(
        2
      )} msgs/s (${messageDelta} messages in ~${sampleDuration}s)`
    );
  }

  return { currentProcessed, throughput };
}

// Simulates multiple devices sending data through the HTTP module
async function testHttpModuleWithDevices(httpPid, deviceCount) {
  console.log(
    `Starting HTTP module scalability test with ${deviceCount} devices...`
  );

  // Reset message counters before starting
  await resetMessageCounters(true);

  // Create clients for each simulated device
  const clients = Array(deviceCount)
    .fill(0)
    .map(() => createMqttClient());

  // Collect CPU and memory samples
  const cpuSamples = [];
  const memorySamples = [];
  const throughputSamples = [];
  const latencies = [];

  // Start time for throughput calculation
  const startTime = performance.now();
  let messageCount = 0;
  let lastSampleTime = startTime;
  let lastSampleCount = 0;

  const monitoringInterval = setInterval(async () => {
    const stats = await monitorPerformance(httpPid, "http");
    cpuSamples.push(stats.cpu);
    memorySamples.push(stats.memory);

    // Collect throughput sample every 5 seconds
    const currentTime = performance.now();
    if (currentTime - lastSampleTime >= 5000) {
      const { currentProcessed, throughput } = await collectThroughputSample(
        "http",
        true,
        startTime,
        lastSampleCount,
        deviceCount
      );
      throughputSamples.push(throughput);
      lastSampleCount = currentProcessed;
      lastSampleTime = currentTime;
    }
  }, SAMPLE_INTERVAL);

  // Fixed number of messages per device
  console.log(`Each device will send ${MESSAGES_PER_DEVICE} messages total`);

  // Send messages from each device as quickly as possible while monitoring backlog
  const devicePromises = clients.map((client, deviceIndex) => {
    return new Promise(async (resolve) => {
      let deviceMessageCount = 0;
      let batchCount = 0;

      // Function to send a batch of messages
      const sendBatch = async () => {
        if (deviceMessageCount >= MESSAGES_PER_DEVICE) {
          return;
        }

        // Check for backlog periodically
        if (++batchCount % BACKLOG_CHECK_THRESHOLD === 0) {
          const processed = await getProcessedMessageCount(true);
          const backlog = messageCount - processed;

          // If backlog is too large, wait for system to catch up
          if (backlog > deviceCount * 5) {
            console.log(
              `Backlog detected (${backlog} messages). Pausing to let system catch up.`
            );
            await new Promise((resolve) =>
              setTimeout(resolve, Math.min(backlog * 10, 5000))
            );
          }
        }

        // Determine batch size (don't exceed remaining messages)
        const batchSize = Math.min(
          BATCH_SIZE,
          MESSAGES_PER_DEVICE - deviceMessageCount
        );
        const batchPromises = [];

        for (let i = 0; i < batchSize; i++) {
          const startReadTime = performance.now();

          const promise = new Promise((resolve) => {
            client.publish(
              `PDVSA_SEDE1_http/string${deviceIndex + 1}`,
              JSON.stringify({
                humedad: Math.random()
              }),
              { qos: QOS_LEVEL },
              () => {
                const endReadTime = performance.now();
                latencies.push(endReadTime - startReadTime);
                resolve();
              }
            );
          });

          batchPromises.push(promise);
        }

        // Wait for all messages in batch to be published
        await Promise.all(batchPromises);

        deviceMessageCount += batchSize;
        messageCount += batchSize;

        // If we still have messages to send, schedule the next batch immediately
        if (deviceMessageCount < MESSAGES_PER_DEVICE) {
          // Use setImmediate for faster sending without flooding the event loop
          setImmediate(sendBatch);
        } else {
          console.log(
            `Device ${
              deviceIndex + 1
            } completed sending ${deviceMessageCount} messages`
          );
          resolve(deviceMessageCount);
        }
      };

      // Start sending messages
      sendBatch();
    });
  });

  // Wait for all devices to finish
  const deviceCounts = await Promise.all(devicePromises);
  const totalSentMessages = deviceCounts.reduce((a, b) => a + b, 0);
  console.log(`Total sent: ${totalSentMessages} HTTP messages`);

  // Wait for all messages to be processed
  const processedCount = await waitForMessageProcessing(
    totalSentMessages,
    true
  );

  // Calculate throughput
  const endTime = performance.now();
  const duration = (endTime - startTime) / 1000; // in seconds
  const actualThroughput = processedCount / duration;

  // Calculate average metrics
  const avgLatency =
    latencies.length > 0
      ? latencies.reduce((a, b) => a + b, 0) / latencies.length
      : 0;

  const avgCpu =
    cpuSamples.length > 0
      ? cpuSamples.reduce((a, b) => a + b, 0) / cpuSamples.length
      : 0;

  const avgMemory =
    memorySamples.length > 0
      ? memorySamples.reduce((a, b) => a + b, 0) / memorySamples.length
      : 0;

  const avgThroughput =
    throughputSamples.length > 0
      ? throughputSamples.reduce((a, b) => a + b, 0) / throughputSamples.length
      : actualThroughput;

  // Save results
  results.http.deviceStats[deviceCount] = {
    latency: avgLatency,
    throughput: avgThroughput,
    cpuUsage: avgCpu,
    memoryUsage: avgMemory,
    processedMessages: processedCount,
    sentMessages: totalSentMessages,
    processingRate: processedCount / totalSentMessages
  };

  // Clean up
  clearInterval(monitoringInterval);
  clients.forEach((client) => client.end());

  console.log(
    `HTTP module scalability test with ${deviceCount} devices completed. ` +
      `Processed ${processedCount}/${totalSentMessages} messages (${Math.round(
        (processedCount / totalSentMessages) * 100
      )}%)`
  );
}

// Simulates multiple devices sending data through the Modbus module
async function testModbusModuleWithDevices(modbusPid, deviceCount) {
  console.log(
    `Starting Modbus module scalability test with ${deviceCount} devices...`
  );

  // Reset message counters before starting
  await resetMessageCounters(false);

  // Find the first sede in config
  const firstSede = config.modbusSedes[0];

  // Create clients for each simulated device
  const clients = Array(deviceCount)
    .fill(0)
    .map(() => createMqttClient());

  // Collect CPU and memory samples
  const cpuSamples = [];
  const memorySamples = [];
  const throughputSamples = [];
  const latencies = [];

  // Start time for throughput calculation
  const startTime = performance.now();
  let messageCount = 0;
  let lastSampleTime = startTime;
  let lastSampleCount = 0;

  const monitoringInterval = setInterval(async () => {
    const stats = await monitorPerformance(modbusPid, "modbus");
    cpuSamples.push(stats.cpu);
    memorySamples.push(stats.memory);

    // Collect throughput sample every 5 seconds
    const currentTime = performance.now();
    if (currentTime - lastSampleTime >= 5000) {
      const { currentProcessed, throughput } = await collectThroughputSample(
        "modbus",
        false,
        startTime,
        lastSampleCount,
        deviceCount
      );
      throughputSamples.push(throughput);
      lastSampleCount = currentProcessed;
      lastSampleTime = currentTime;
    }
  }, SAMPLE_INTERVAL);

  // Fixed number of messages per device
  console.log(`Each device will send ${MESSAGES_PER_DEVICE} messages total`);

  // Send messages from each device as quickly as possible while monitoring backlog
  const devicePromises = clients.map((client, deviceIndex) => {
    return new Promise(async (resolve) => {
      let deviceMessageCount = 0;
      let batchCount = 0;

      // Function to send a batch of messages
      const sendBatch = async () => {
        if (deviceMessageCount >= MESSAGES_PER_DEVICE) {
          return;
        }

        // Check for backlog periodically
        if (++batchCount % BACKLOG_CHECK_THRESHOLD === 0) {
          const processed = await getProcessedMessageCount(false);
          const backlog = messageCount - processed;

          // If backlog is too large, wait for system to catch up
          if (backlog > deviceCount * 5) {
            console.log(
              `Backlog detected (${backlog} messages). Pausing to let system catch up.`
            );
            await new Promise((resolve) =>
              setTimeout(resolve, Math.min(backlog * 10, 5000))
            );
          }
        }

        // Determine batch size (don't exceed remaining messages)
        const batchSize = Math.min(
          BATCH_SIZE,
          MESSAGES_PER_DEVICE - deviceMessageCount
        );
        const batchPromises = [];

        for (let i = 0; i < batchSize; i++) {
          const startReadTime = performance.now();

          // Generate a value within Modbus register range (-32768 to 32767)
          const value = Math.floor(Math.random() * 65535) - 32768;

          const promise = new Promise((resolve) => {
            client.publish(
              `${firstSede.nombre}/${deviceIndex + 1}/holding/${i % 100}`,
              String(value),
              { qos: QOS_LEVEL },
              () => {
                const endReadTime = performance.now();
                latencies.push(endReadTime - startReadTime);
                resolve();
              }
            );
          });

          batchPromises.push(promise);
        }

        // Wait for all messages in batch to be published
        await Promise.all(batchPromises);

        deviceMessageCount += batchSize;
        messageCount += batchSize;

        // If we still have messages to send, schedule the next batch immediately
        if (deviceMessageCount < MESSAGES_PER_DEVICE) {
          // Use setImmediate for faster sending without flooding the event loop
          setImmediate(sendBatch);
        } else {
          console.log(
            `Device ${
              deviceIndex + 1
            } completed sending ${deviceMessageCount} messages`
          );
          resolve(deviceMessageCount);
        }
      };

      // Start sending messages
      sendBatch();
    });
  });

  // Wait for all devices to finish
  const deviceCounts = await Promise.all(devicePromises);
  const totalSentMessages = deviceCounts.reduce((a, b) => a + b, 0);
  console.log(`Total sent: ${totalSentMessages} MODBUS messages`);

  // Wait for all messages to be processed
  const processedCount = await waitForMessageProcessing(
    totalSentMessages,
    false
  );

  // Calculate throughput
  const endTime = performance.now();
  const duration = (endTime - startTime) / 1000; // in seconds
  const actualThroughput = processedCount / duration;

  // Calculate average metrics
  const avgLatency =
    latencies.length > 0
      ? latencies.reduce((a, b) => a + b, 0) / latencies.length
      : 0;

  const avgCpu =
    cpuSamples.length > 0
      ? cpuSamples.reduce((a, b) => a + b, 0) / cpuSamples.length
      : 0;

  const avgMemory =
    memorySamples.length > 0
      ? memorySamples.reduce((a, b) => a + b, 0) / memorySamples.length
      : 0;

  const avgThroughput =
    throughputSamples.length > 0
      ? throughputSamples.reduce((a, b) => a + b, 0) / throughputSamples.length
      : actualThroughput;

  // Save results
  results.modbus.deviceStats[deviceCount] = {
    latency: avgLatency,
    throughput: avgThroughput,
    cpuUsage: avgCpu,
    memoryUsage: avgMemory,
    processedMessages: processedCount,
    sentMessages: totalSentMessages,
    processingRate: processedCount / totalSentMessages
  };

  // Clean up
  clearInterval(monitoringInterval);
  clients.forEach((client) => client.end());

  console.log(
    `MODBUS module scalability test with ${deviceCount} devices completed. ` +
      `Processed ${processedCount}/${totalSentMessages} messages (${Math.round(
        (processedCount / totalSentMessages) * 100
      )}%)`
  );
}

// Generate report with scalability results
function generateScalabilityReport() {
  console.log("Scalability Test Results:");
  console.log("=========================");

  for (const module of TEST_MODULES) {
    console.log(`\n${module.toUpperCase()} Module Scalability:`);
    console.log(
      "----------------------------------------------------------------------"
    );
    console.log(
      "| Dispositivos | Latencia (ms) | mensajes/s | CPU (%) | memoria (MB) |"
    );
    console.log(
      "|--------------|---------------|------------|---------|--------------|"
    );

    for (const deviceCount of DEVICE_COUNTS) {
      const stats = results[module].deviceStats[deviceCount] || {
        latency: 0,
        throughput: 0,
        cpuUsage: 0,
        memoryUsage: 0,
        processingRate: 0
      };

      console.log(
        `| ${String(deviceCount).padEnd(12)} | ${stats.latency
          .toFixed(2)
          .padEnd(13)} | ${stats.throughput
          .toFixed(2)
          .padEnd(10)} | ${stats.cpuUsage
          .toFixed(2)
          .padEnd(7)} | ${stats.memoryUsage.toFixed(2).padEnd(12)} |`
      );
    }

    console.log(
      "----------------------------------------------------------------------"
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
  // Setup the stats MQTT client
  await setupStatsMqttClient();

  // Test each module with different device counts
  for (const module of TEST_MODULES) {
    for (const deviceCount of DEVICE_COUNTS) {
      if (module === "http") {
        await testHttpModuleWithDevices(httpPid, deviceCount);
      } else if (module === "modbus") {
        await testModbusModuleWithDevices(modbusPid, deviceCount);
      }

      // Add a pause between tests to let the system cool down
      console.log(
        `Waiting 30 seconds for system to stabilize before the next test...`
      );
      await new Promise((resolve) => setTimeout(resolve, 30000));
    }
  }

  // Clean up the stats client
  if (statsMqttClient) {
    statsMqttClient.end();
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
