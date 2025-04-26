/**
 * Scalability Test with Different Data Types
 *
 * Objective: Evaluate gateway performance when handling different data types
 * (integers, decimals, booleans, strings, JSON) with a high number of devices and messages.
 *
 * Configuration: 1000 simulated devices sending messages with different data types
 * at a rate of 50 messages/second per device.
 */

"use strict";

const mqtt = require("mqtt");
const fs = require("fs");
const path = require("path");
const { performance } = require("perf_hooks");
const pidusage = require("pidusage");
const config = require("./config.json");

// Test configuration
const TEST_DURATION = 60000; // 1 minute test duration
const SAMPLE_INTERVAL = 1000; // 1 second sampling interval for CPU/mem
const TEST_MODULES = ["http", "modbus"];
const SIMULATED_DEVICES = 1000; // Number of simulated devices
const CONCURRENT_CLIENTS = 20; // Number of actual MQTT clients to distribute the load
const DEVICES_PER_CLIENT = Math.ceil(SIMULATED_DEVICES / CONCURRENT_CLIENTS);
const MESSAGES_PER_SECOND_PER_DEVICE = 50; // Target message rate per device
const MESSAGE_VERIFICATION_TIMEOUT = 60000; // 60 seconds timeout for message processing verification
const PROCESSING_CHECK_INTERVAL = 5000; // Check processing progress every 5 seconds

// Rate limiting and throttling parameters
const BATCH_SIZE = 100; // Messages to send in a batch
const THROTTLE_DELAY = 50; // ms delay between batches to prevent overwhelming the broker

// Topics for stats
const HTTP_STATS_REQUEST_TOPIC = "http_module/stats/request";
const HTTP_STATS_RESPONSE_TOPIC = "http_module/stats/response";
const HTTP_STATS_RESET_TOPIC = "http_module/stats/reset";
const MODBUS_STATS_REQUEST_TOPIC = "modbus_module/stats/request";
const MODBUS_STATS_RESPONSE_TOPIC = "modbus_module/stats/response";
const MODBUS_STATS_RESET_TOPIC = "modbus_module/stats/reset";

// Data type definitions for the test
const DATA_TYPES = [
  "integer", // Integer values
  "decimal", // Floating point values
  "boolean", // Boolean values
  "string", // String values
  "json" // JSON structures
];

// Results storage
const results = {
  http: {
    latencies: [],
    throughput: [],
    cpuUsage: [],
    memoryUsage: [],
    throughputSamples: [],
    dataTypePerformance: {}
  },
  modbus: {
    latencies: [],
    throughput: [],
    cpuUsage: [],
    memoryUsage: [],
    throughputSamples: [],
    dataTypePerformance: {}
  }
};

// Initialize data type performance metrics
DATA_TYPES.forEach((type) => {
  results.http.dataTypePerformance[type] = {
    latencies: [],
    processed: 0,
    sent: 0
  };
  results.modbus.dataTypePerformance[type] = {
    latencies: [],
    processed: 0,
    sent: 0
  };
});

// MQTT connection setup
const mqttConnection = `mqtt://${process.env.MQTT_HOST || config.mqttHost}:${
  process.env.MQTT_PORT || config.mqttPort
}`;
const mqttCredentials = {
  password: process.env.MQTT_PASS || config.mqttPass,
  username: process.env.MQTT_USER || config.mqttUser
};

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
  console.log(`Connecting ${count} MQTT clients for ${moduleType} module...`);

  for (let i = 0; i < count; i++) {
    const clientId = `scalability-test-${moduleType}-client-${i}-${Date.now()}`;
    const client = mqtt.connect(mqttConnection, {
      ...mqttCredentials,
      clientId,
      keepalive: 60
    });

    await new Promise((resolve, reject) => {
      client.on("connect", () => {
        console.log(`Client ${i + 1}/${count} connected`);
        resolve();
      });
      client.on("error", (err) => {
        console.error(`Client ${i} connection error:`, err);
        reject(err);
      });

      // Set timeout for connection
      setTimeout(
        () => reject(new Error(`Connection timeout for client ${i}`)),
        10000
      );
    });

    clients.push(client);
  }

  console.log(`${clients.length} MQTT clients connected successfully`);
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

// Generate data based on type
function generateData(dataType) {
  switch (dataType) {
    case "integer":
      return Math.floor(Math.random() * 1000);
    case "decimal":
      return parseFloat((Math.random() * 100).toFixed(2));
    case "boolean":
      return Math.random() > 0.5;
    case "string":
      return `test-string-${Math.random().toString(36).substring(2, 10)}`;
    case "json":
      return {
        timestamp: Date.now(),
        values: {
          temperature: parseFloat((15 + Math.random() * 15).toFixed(2)),
          humidity: parseFloat((30 + Math.random() * 50).toFixed(2)),
          pressure: parseFloat((980 + Math.random() * 40).toFixed(1)),
          status: Math.random() > 0.5 ? "active" : "standby"
        }
      };
    default:
      return 0;
  }
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

  const maxWaitTime = 180000; // Extended max wait to 3 minutes for high volume
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

// Collect throughput sample
async function collectThroughputSample(
  moduleType,
  isHttp,
  startTime,
  lastMessageCount
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
      `[${elapsedSeconds.toFixed(
        1
      )}s] Current throughput sample: ${throughput.toFixed(
        2
      )} msgs/s (${messageDelta} messages in ~${sampleDuration}s)`
    );
    results[moduleType].throughputSamples.push(throughput);
  }

  return currentProcessed;
}

// Test HTTP module with different data types
async function testHttpScalability(httpPid) {
  console.log(
    "Starting HTTP module scalability test with different data types..."
  );

  // Reset message counters before starting
  await resetMessageCounters(true);

  let totalMessageCount = 0;
  const startTime = performance.now();
  let lastSampleTime = startTime;
  let lastSampleCount = 0;

  // Start performance monitoring
  const monitoringInterval = setInterval(async () => {
    await monitorPerformance(httpPid, "http");

    // Collect throughput sample every 5 seconds
    const currentTime = performance.now();
    if (currentTime - lastSampleTime >= 5000) {
      lastSampleCount = await collectThroughputSample(
        "http",
        true,
        startTime,
        lastSampleCount
      );
      lastSampleTime = currentTime;
    }
  }, SAMPLE_INTERVAL);

  try {
    // Connect MQTT clients
    const clients = await connectMqttClients(CONCURRENT_CLIENTS, "http");
    const testEndTime = startTime + TEST_DURATION;

    // Run parallel publishing from multiple clients
    const clientPromises = clients.map(async (client, clientIndex) => {
      let clientMessageCount = 0;
      const deviceBaseIndex = clientIndex * DEVICES_PER_CLIENT;
      const devicesForThisClient = Math.min(
        DEVICES_PER_CLIENT,
        SIMULATED_DEVICES - deviceBaseIndex
      );

      console.log(
        `Client ${clientIndex} simulating ${devicesForThisClient} devices (${deviceBaseIndex} to ${
          deviceBaseIndex + devicesForThisClient - 1
        })`
      );

      // Calculate message rate for this client to meet target rate across all devices
      const clientMessagesPerSecond =
        devicesForThisClient * MESSAGES_PER_SECOND_PER_DEVICE;
      const messagesPerBatch = Math.min(
        BATCH_SIZE,
        Math.ceil(clientMessagesPerSecond / 5)
      ); // At most 1/5 second worth of messages per batch

      let lastBatchTime = performance.now();
      let dataTypeIndex = 0;

      while (performance.now() < testEndTime) {
        const currentTime = performance.now();

        // Enforce rate limiting
        const timeSinceLastBatch = currentTime - lastBatchTime;
        const targetTimeBetweenBatches =
          (messagesPerBatch * 1000) / clientMessagesPerSecond;

        if (timeSinceLastBatch < targetTimeBetweenBatches) {
          await new Promise((resolve) =>
            setTimeout(resolve, targetTimeBetweenBatches - timeSinceLastBatch)
          );
        }

        // Send a batch of messages across simulated devices
        const batchPromises = [];
        for (let i = 0; i < messagesPerBatch; i++) {
          // Select device and data type
          const deviceId = deviceBaseIndex + (i % devicesForThisClient);
          const dataType = DATA_TYPES[dataTypeIndex % DATA_TYPES.length];
          dataTypeIndex++;

          const data = generateData(dataType);
          const startSendTime = performance.now();

          try {
            const promise = new Promise((resolve) => {
              const payload =
                typeof data === "object" ? JSON.stringify(data) : String(data);
              client.publish(
                `PDVSA_SEDE1_http/device${deviceId}/${dataType}`,
                payload,
                { qos: 1 },
                () => {
                  const endSendTime = performance.now();
                  const latency = endSendTime - startSendTime;
                  results.http.latencies.push(latency);
                  results.http.dataTypePerformance[dataType].latencies.push(
                    latency
                  );
                  results.http.dataTypePerformance[dataType].sent++;
                  resolve();
                }
              );
            });

            batchPromises.push(promise);
            clientMessageCount++;
          } catch (error) {
            console.error(
              `Client ${clientIndex} error publishing message for device ${deviceId}:`,
              error
            );
          }
        }

        // Wait for all messages in batch to be published
        await Promise.all(batchPromises);

        // Record time after batch
        lastBatchTime = performance.now();

        // Add small throttling delay to avoid overwhelming broker
        await new Promise((resolve) => setTimeout(resolve, THROTTLE_DELAY));

        // Log progress occasionally
        if (clientMessageCount % 1000 === 0) {
          console.log(
            `Client ${clientIndex}: ${clientMessageCount} HTTP messages sent`
          );
        }
      }

      return clientMessageCount;
    });

    // Wait for all clients to finish
    const clientMessageCounts = await Promise.all(clientPromises);
    totalMessageCount = clientMessageCounts.reduce(
      (sum, count) => sum + count,
      0
    );

    console.log(`Total messages sent to HTTP module: ${totalMessageCount}`);

    // Wait for all messages to be processed
    const processedCount = await waitForMessageProcessing(
      totalMessageCount,
      true
    );

    // Calculate overall throughput
    const endTime = performance.now();
    const durationSeconds = (endTime - startTime) / 1000;
    const actualThroughput = processedCount / durationSeconds;

    // Add final throughput
    if (results.http.throughputSamples.length > 0) {
      results.http.throughputSamples.push(actualThroughput);
      results.http.throughput = results.http.throughputSamples;
    } else {
      results.http.throughput.push(actualThroughput);
    }

    console.log(
      `HTTP throughput: ${actualThroughput.toFixed(
        2
      )} msgs/s (${processedCount} messages in ${durationSeconds.toFixed(2)}s)`
    );

    // Clean up clients
    for (const client of clients) {
      client.end();
    }
  } catch (error) {
    console.error("Error in HTTP scalability test:", error);
  } finally {
    clearInterval(monitoringInterval);
    console.log(
      `HTTP module scalability test completed with ${totalMessageCount} messages sent.`
    );
  }
}

// Test Modbus module with different data types
async function testModbusScalability(modbusPid) {
  console.log(
    "Starting Modbus module scalability test with different data types..."
  );

  // Reset message counters before starting
  await resetMessageCounters(false);

  let totalMessageCount = 0;
  const startTime = performance.now();
  let lastSampleTime = startTime;
  let lastSampleCount = 0;

  // Find first sede in config for Modbus testing
  const firstSede = config.modbusSedes[0];

  // Start performance monitoring
  const monitoringInterval = setInterval(async () => {
    await monitorPerformance(modbusPid, "modbus");

    // Collect throughput sample every 5 seconds
    const currentTime = performance.now();
    if (currentTime - lastSampleTime >= 5000) {
      lastSampleCount = await collectThroughputSample(
        "modbus",
        false,
        startTime,
        lastSampleCount
      );
      lastSampleTime = currentTime;
    }
  }, SAMPLE_INTERVAL);

  try {
    // Connect MQTT clients
    const clients = await connectMqttClients(CONCURRENT_CLIENTS, "modbus");
    const testEndTime = startTime + TEST_DURATION;

    // Run parallel publishing from multiple clients
    const clientPromises = clients.map(async (client, clientIndex) => {
      let clientMessageCount = 0;
      const deviceBaseIndex = clientIndex * DEVICES_PER_CLIENT;
      const devicesForThisClient = Math.min(
        DEVICES_PER_CLIENT,
        SIMULATED_DEVICES - deviceBaseIndex
      );

      console.log(
        `Client ${clientIndex} simulating ${devicesForThisClient} Modbus devices (${deviceBaseIndex} to ${
          deviceBaseIndex + devicesForThisClient - 1
        })`
      );

      // Calculate message rate for this client to meet target rate across all devices
      const clientMessagesPerSecond =
        devicesForThisClient * MESSAGES_PER_SECOND_PER_DEVICE;
      const messagesPerBatch = Math.min(
        BATCH_SIZE,
        Math.ceil(clientMessagesPerSecond / 5)
      ); // At most 1/5 second worth of messages per batch

      let lastBatchTime = performance.now();
      let dataTypeIndex = 0;
      let registerTypeIndex = 0;
      const registerTypes = ["holding", "input", "coil", "discrete"];

      while (performance.now() < testEndTime) {
        const currentTime = performance.now();

        // Enforce rate limiting
        const timeSinceLastBatch = currentTime - lastBatchTime;
        const targetTimeBetweenBatches =
          (messagesPerBatch * 1000) / clientMessagesPerSecond;

        if (timeSinceLastBatch < targetTimeBetweenBatches) {
          await new Promise((resolve) =>
            setTimeout(resolve, targetTimeBetweenBatches - timeSinceLastBatch)
          );
        }

        // Send a batch of messages across simulated devices
        const batchPromises = [];
        for (let i = 0; i < messagesPerBatch; i++) {
          // Select device, register type, and data type
          const deviceId = deviceBaseIndex + (i % devicesForThisClient);
          const dataType = DATA_TYPES[dataTypeIndex % DATA_TYPES.length];
          const registerType =
            registerTypes[registerTypeIndex % registerTypes.length];
          const registerAddress = i % 100; // Use 100 different register addresses

          dataTypeIndex++;
          registerTypeIndex++;

          const data = generateData(dataType);
          const startSendTime = performance.now();

          try {
            // For Modbus, coil and discrete inputs only accept boolean values
            let payload;
            if (registerType === "coil" || registerType === "discrete") {
              // Convert any data type to boolean for coil/discrete
              payload =
                typeof data === "boolean"
                  ? String(data ? 1 : 0)
                  : String(data ? 1 : 0);
            } else {
              // For holding and input registers, convert appropriately
              if (typeof data === "object") {
                // For JSON data, just use a numeric value between 0-65535 for Modbus registers
                payload = String(Math.floor(Math.random() * 65535));
              } else if (typeof data === "boolean") {
                payload = String(data ? 1 : 0);
              } else if (typeof data === "string") {
                // For string data, just use a register value for Modbus
                payload = String(Math.floor(Math.random() * 65535));
              } else {
                // For numeric data, ensure it's within Modbus register range
                const numValue = typeof data === "number" ? data : 0;
                payload = String(
                  Math.min(65535, Math.max(0, Math.floor(numValue)))
                );
              }
            }

            const promise = new Promise((resolve) => {
              client.publish(
                `${firstSede.nombre}/${deviceId}/${registerType}/${registerAddress}`,
                payload,
                { qos: 1 },
                () => {
                  const endSendTime = performance.now();
                  const latency = endSendTime - startSendTime;
                  results.modbus.latencies.push(latency);
                  results.modbus.dataTypePerformance[dataType].latencies.push(
                    latency
                  );
                  results.modbus.dataTypePerformance[dataType].sent++;
                  resolve();
                }
              );
            });

            batchPromises.push(promise);
            clientMessageCount++;
          } catch (error) {
            console.error(
              `Client ${clientIndex} error publishing Modbus message for device ${deviceId}:`,
              error
            );
          }
        }

        // Wait for all messages in batch to be published
        await Promise.all(batchPromises);

        // Record time after batch
        lastBatchTime = performance.now();

        // Add small throttling delay to avoid overwhelming broker
        await new Promise((resolve) => setTimeout(resolve, THROTTLE_DELAY));

        // Log progress occasionally
        if (clientMessageCount % 1000 === 0) {
          console.log(
            `Client ${clientIndex}: ${clientMessageCount} MODBUS messages sent`
          );
        }
      }

      return clientMessageCount;
    });

    // Wait for all clients to finish
    const clientMessageCounts = await Promise.all(clientPromises);
    totalMessageCount = clientMessageCounts.reduce(
      (sum, count) => sum + count,
      0
    );

    console.log(`Total messages sent to MODBUS module: ${totalMessageCount}`);

    // Wait for all messages to be processed
    const processedCount = await waitForMessageProcessing(
      totalMessageCount,
      false
    );

    // Calculate overall throughput
    const endTime = performance.now();
    const durationSeconds = (endTime - startTime) / 1000;
    const actualThroughput = processedCount / durationSeconds;

    // Add final throughput
    if (results.modbus.throughputSamples.length > 0) {
      results.modbus.throughputSamples.push(actualThroughput);
      results.modbus.throughput = results.modbus.throughputSamples;
    } else {
      results.modbus.throughput.push(actualThroughput);
    }

    console.log(
      `MODBUS throughput: ${actualThroughput.toFixed(
        2
      )} msgs/s (${processedCount} messages in ${durationSeconds.toFixed(2)}s)`
    );

    // Clean up clients
    for (const client of clients) {
      client.end();
    }
  } catch (error) {
    console.error("Error in MODBUS scalability test:", error);
  } finally {
    clearInterval(monitoringInterval);
    console.log(
      `MODBUS module scalability test completed with ${totalMessageCount} messages sent.`
    );
  }
}

// Calculate statistics for arrays of metrics
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
  const report = {
    summary: {},
    dataTypes: {}
  };

  for (const module of TEST_MODULES) {
    // Overall performance metrics
    report.summary[module] = {
      latency: calculateStats(results[module].latencies),
      throughput: calculateStats(results[module].throughput),
      cpuUsage: calculateStats(results[module].cpuUsage),
      memoryUsage: calculateStats(results[module].memoryUsage)
    };

    // Per data type metrics
    report.dataTypes[module] = {};
    for (const dataType of DATA_TYPES) {
      report.dataTypes[module][dataType] = {
        latency: calculateStats(
          results[module].dataTypePerformance[dataType].latencies
        ),
        messagesSent: results[module].dataTypePerformance[dataType].sent
      };
    }
  }

  // Print report summary
  console.log("\n\n============= SCALABILITY TEST RESULTS =============");
  console.log(
    `Test Configuration: ${SIMULATED_DEVICES} devices at ${MESSAGES_PER_SECOND_PER_DEVICE} msgs/sec each, mixed data types`
  );
  console.log("====================================================\n");

  // Summary table for each module
  for (const module of TEST_MODULES) {
    console.log(`\n${module.toUpperCase()} MODULE SUMMARY:`);
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
      `| Latencia (ms)        | ${report.summary[module].latency.avg
        .toFixed(2)
        .padEnd(13)} | ${report.summary[module].latency.min
        .toFixed(2)
        .padEnd(13)} | ${report.summary[module].latency.max
        .toFixed(2)
        .padEnd(13)} | ${report.summary[module].latency.stdDev
        .toFixed(2)
        .padEnd(20)} |`
    );
    console.log(
      `| Rendimiento (msgs/s) | ${report.summary[module].throughput.avg
        .toFixed(2)
        .padEnd(13)} | ${report.summary[module].throughput.min
        .toFixed(2)
        .padEnd(13)} | ${report.summary[module].throughput.max
        .toFixed(2)
        .padEnd(13)} | ${report.summary[module].throughput.stdDev
        .toFixed(2)
        .padEnd(20)} |`
    );
    console.log(
      `| Uso de CPU (%)       | ${report.summary[module].cpuUsage.avg
        .toFixed(2)
        .padEnd(13)} | ${report.summary[module].cpuUsage.min
        .toFixed(2)
        .padEnd(13)} | ${report.summary[module].cpuUsage.max
        .toFixed(2)
        .padEnd(13)} | ${report.summary[module].cpuUsage.stdDev
        .toFixed(2)
        .padEnd(20)} |`
    );
    console.log(
      `| Uso de memoria (MB)  | ${report.summary[module].memoryUsage.avg
        .toFixed(2)
        .padEnd(13)} | ${report.summary[module].memoryUsage.min
        .toFixed(2)
        .padEnd(13)} | ${report.summary[module].memoryUsage.max
        .toFixed(2)
        .padEnd(13)} | ${report.summary[module].memoryUsage.stdDev
        .toFixed(2)
        .padEnd(20)} |`
    );
    console.log(
      "----------------------------------------------------------------------------------"
    );
  }

  // Data type specific performance
  console.log("\n\nPERFORMANCE BY DATA TYPE:");
  console.log(
    "=================================================================================="
  );

  for (const module of TEST_MODULES) {
    console.log(`\n${module.toUpperCase()} MODULE - DATA TYPE PERFORMANCE:`);
    console.log(
      "-----------------------------------------------------------------------------------"
    );
    console.log(
      "| Tipo de Dato | Mensajes Enviados | Latencia Prom (ms) | Latencia Min | Latencia Max |"
    );
    console.log(
      "|--------------|-------------------|-------------------|--------------|--------------|"
    );

    for (const dataType of DATA_TYPES) {
      const stats = report.dataTypes[module][dataType];
      console.log(
        `| ${dataType.padEnd(12)} | ${stats.messagesSent
          .toString()
          .padEnd(17)} | ${stats.latency.avg
          .toFixed(2)
          .padEnd(17)} | ${stats.latency.min
          .toFixed(2)
          .padEnd(12)} | ${stats.latency.max.toFixed(2).padEnd(12)} |`
      );
    }
    console.log(
      "-----------------------------------------------------------------------------------"
    );
  }

  // Save results to JSON file
  fs.writeFileSync(
    path.join(__dirname, "scalability_results.json"),
    JSON.stringify(report, null, 2)
  );
  console.log("\nDetailed results saved to scalability_results.json");
}

// Main function to run the scalability tests
async function runScalabilityTests(httpPid, modbusPid) {
  console.log(`
====================================================
  STARTING SCALABILITY TEST WITH DIFFERENT DATA TYPES
====================================================
Simulating ${SIMULATED_DEVICES} devices sending at ${MESSAGES_PER_SECOND_PER_DEVICE} msgs/sec
Data types: ${DATA_TYPES.join(", ")}
Test duration: ${TEST_DURATION / 1000} seconds
====================================================
`);

  // Setup the stats MQTT client first
  await setupStatsMqttClient();

  // Run HTTP module test
  await testHttpScalability(httpPid);

  // Wait for system to stabilize
  console.log(
    "Waiting 30 seconds for system to stabilize before Modbus test..."
  );
  await new Promise((resolve) => setTimeout(resolve, 30000));

  // Run Modbus module test
  await testModbusScalability(modbusPid);

  // Generate report
  generateReport();

  // Clean up
  if (statsMqttClient) {
    statsMqttClient.end();
  }

  console.log(
    "Scalability tests with different data types completed successfully."
  );
}

// Execute the scalability tests if this script is run directly
if (require.main === module) {
  const args = process.argv.slice(2);
  const httpPid = parseInt(args[0], 10);
  const modbusPid = parseInt(args[1], 10);

  if (!httpPid || !modbusPid) {
    console.error(
      "Usage: node scalability_data_types.js <httpPid> <modbusPid>"
    );
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
