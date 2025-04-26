/**
 * Scalability Test with Different Data Types
 *
 * Objective: Evaluate gateway performance when handling different data types
 * (integers, decimals, booleans, strings, JSON) with a controlled message load.
 *
 * Configuration: 1 device sending exactly 1000 messages for each data type (5000 total)
 * with throttling to avoid flooding the service while still providing meaningful metrics.
 */

"use strict";

const mqtt = require("mqtt");
const fs = require("fs");
const path = require("path");
const { performance } = require("perf_hooks");
const pidusage = require("pidusage");
const config = require("./config.json");

// Test configuration
const SAMPLE_INTERVAL = 1000; // 1 second sampling interval for CPU/mem
const TEST_MODULES = ["http", "modbus"];
const MESSAGES_PER_DATA_TYPE = 1000; // Send 1000 messages for each data type for better metrics
const MESSAGE_VERIFICATION_TIMEOUT = 120000; // 2 minutes timeout for message processing verification
const PROCESSING_CHECK_INTERVAL = 3000; // Check processing progress every 3 seconds

// Rate limiting and throttling parameters
const BATCH_SIZE = 25; // Batch size to avoid overwhelming the broker
const THROTTLE_DELAY = 100; // Delay between batches

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
    systemLatency: {}, // Track full processing latency by data type
    throughput: [],
    cpuUsage: [],
    memoryUsage: [],
    throughputSamples: [],
    dataTypePerformance: {}
  },
  modbus: {
    systemLatency: {}, // Track full processing latency by data type
    throughput: [],
    cpuUsage: [],
    memoryUsage: [],
    throughputSamples: [],
    dataTypePerformance: {}
  }
};

// Initialize data type performance metrics
DATA_TYPES.forEach((type) => {
  results.http.systemLatency[type] = []; // Array of processing latencies for this data type
  results.modbus.systemLatency[type] = []; // Array of processing latencies for this data type

  results.http.dataTypePerformance[type] = {
    processingStartTime: 0, // When processing started for this data type
    processingEndTime: 0, // When processing completed for this data type
    sent: 0, // Number of messages sent
    processed: 0 // Number of messages processed
  };

  results.modbus.dataTypePerformance[type] = {
    processingStartTime: 0,
    processingEndTime: 0,
    sent: 0,
    processed: 0
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

// Connect MQTT client
async function connectMqttClient(moduleType) {
  console.log(`Connecting MQTT client for ${moduleType} module...`);

  const clientId = `scalability-test-${moduleType}-client-${Date.now()}`;
  const client = mqtt.connect(mqttConnection, {
    ...mqttCredentials,
    clientId,
    keepalive: 60
  });

  return new Promise((resolve, reject) => {
    client.on("connect", () => {
      console.log(`MQTT client connected for ${moduleType} module`);
      resolve(client);
    });
    client.on("error", (err) => {
      console.error(`MQTT client connection error:`, err);
      reject(err);
    });

    // Set timeout for connection
    setTimeout(
      () => reject(new Error(`Connection timeout for MQTT client`)),
      10000
    );
  });
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
async function waitForMessageProcessing(
  totalSent,
  isHttp,
  moduleType,
  dataType
) {
  console.log(
    `Waiting for ${totalSent} messages to be processed by ${
      isHttp ? "HTTP" : "MODBUS"
    } module...`
  );

  // Store processing start time for latency calculation
  results[moduleType].dataTypePerformance[dataType].processingStartTime =
    performance.now();

  const maxWaitTime = 180000; // Up to 3 minutes wait time
  const startTime = performance.now();
  let processed = 0;
  let timeWaiting = 0;
  let lastProcessedCount = 0;
  let stagnantCount = 0;

  while (processed < totalSent && timeWaiting < maxWaitTime) {
    processed = await getProcessedMessageCount(isHttp);

    // Update processed count in results
    results[moduleType].dataTypePerformance[dataType].processed = processed;

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

  // Store processing end time for latency calculation
  const endTime = performance.now();
  results[moduleType].dataTypePerformance[dataType].processingEndTime = endTime;

  // Calculate and store system latency (full processing time)
  const processingTime =
    endTime -
    results[moduleType].dataTypePerformance[dataType].processingStartTime;
  results[moduleType].systemLatency[dataType].push(processingTime);

  console.log(
    `Processing time for ${dataType}: ${processingTime.toFixed(2)} ms`
  );

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
    // Connect a single MQTT client
    const client = await connectMqttClient("http");

    // Process each data type sequentially, sending exactly MESSAGES_PER_DATA_TYPE messages for each
    for (const dataType of DATA_TYPES) {
      console.log(`\n===== Testing HTTP with data type: ${dataType} =====`);
      console.log(`Sending ${MESSAGES_PER_DATA_TYPE} HTTP messages...`);

      // Reset counters for this data type test
      await resetMessageCounters(true);

      let messagesSent = 0;
      let batchCount = 0;

      // Record specific start time for this data type
      const dataTypeStartTime = performance.now();

      // Send messages in batches
      while (messagesSent < MESSAGES_PER_DATA_TYPE) {
        const batchSize = Math.min(
          BATCH_SIZE,
          MESSAGES_PER_DATA_TYPE - messagesSent
        );
        const batchPromises = [];

        for (let i = 0; i < batchSize; i++) {
          const data = generateData(dataType);

          try {
            const promise = new Promise((resolve) => {
              const payload =
                typeof data === "object" ? JSON.stringify(data) : String(data);
              client.publish(
                `PDVSA_SEDE1_http/device1/${dataType}`, // Only using device1
                payload,
                { qos: 1 },
                () => {
                  resolve();
                }
              );
            });

            batchPromises.push(promise);
            messagesSent++;
            results.http.dataTypePerformance[dataType].sent++;
            totalMessageCount++;
          } catch (error) {
            console.error(
              `Error publishing HTTP message with data type ${dataType}:`,
              error
            );
          }
        }

        // Wait for all messages in batch to be published
        await Promise.all(batchPromises);

        batchCount++;
        if (batchCount % 5 === 0) {
          console.log(
            `HTTP: ${messagesSent}/${MESSAGES_PER_DATA_TYPE} ${dataType} messages sent`
          );
        }

        // Add throttling delay between batches
        await new Promise((resolve) => setTimeout(resolve, THROTTLE_DELAY));
      }

      console.log(
        `Completed sending ${messagesSent} HTTP messages with data type: ${dataType}`
      );

      // Wait for all messages to be processed and measure processing time
      const processedCount = await waitForMessageProcessing(
        messagesSent,
        true,
        "http",
        dataType
      );

      // Calculate throughput for this data type
      const dataTypeEndTime = performance.now();
      const dataTypeDurationSeconds =
        (dataTypeEndTime - dataTypeStartTime) / 1000;
      const dataTypeThroughput = processedCount / dataTypeDurationSeconds;

      console.log(
        `HTTP ${dataType} throughput: ${dataTypeThroughput.toFixed(
          2
        )} msgs/s ` +
          `(${processedCount} messages in ${dataTypeDurationSeconds.toFixed(
            2
          )}s)`
      );

      // Wait a bit before moving to next data type
      console.log(`Waiting before testing next data type...`);
      await new Promise((resolve) => setTimeout(resolve, 5000));
    }

    console.log(`\nTotal HTTP messages sent: ${totalMessageCount}`);

    // Calculate overall throughput
    const endTime = performance.now();
    const durationSeconds = (endTime - startTime) / 1000;
    const actualThroughput = totalMessageCount / durationSeconds;

    // Add final throughput
    if (results.http.throughputSamples.length > 0) {
      results.http.throughputSamples.push(actualThroughput);
      results.http.throughput = results.http.throughputSamples;
    } else {
      results.http.throughput.push(actualThroughput);
    }

    console.log(
      `Overall HTTP throughput: ${actualThroughput.toFixed(2)} msgs/s ` +
        `(${totalMessageCount} messages in ${durationSeconds.toFixed(2)}s)`
    );

    // Clean up client
    client.end();
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
    // Connect a single MQTT client
    const client = await connectMqttClient("modbus");

    // Define register types to use for Modbus
    const registerTypes = ["holding", "input", "coil", "discrete"];

    // Process each data type sequentially
    for (const dataType of DATA_TYPES) {
      console.log(`\n===== Testing MODBUS with data type: ${dataType} =====`);
      console.log(`Sending ${MESSAGES_PER_DATA_TYPE} Modbus messages...`);

      // Reset counters for this data type test
      await resetMessageCounters(false);

      let messagesSent = 0;
      let batchCount = 0;
      let registerTypeIndex = 0;

      // Record specific start time for this data type
      const dataTypeStartTime = performance.now();

      // Send messages in batches
      while (messagesSent < MESSAGES_PER_DATA_TYPE) {
        const batchSize = Math.min(
          BATCH_SIZE,
          MESSAGES_PER_DATA_TYPE - messagesSent
        );
        const batchPromises = [];

        for (let i = 0; i < batchSize; i++) {
          // Cycle through register types
          const registerType =
            registerTypes[registerTypeIndex % registerTypes.length];
          registerTypeIndex++;

          // Use different register addresses to simulate real usage
          const registerAddress = i % 100;

          const data = generateData(dataType);

          try {
            // Format payload based on register type
            let payload;
            if (registerType === "coil" || registerType === "discrete") {
              // Convert any data type to boolean for coil/discrete
              payload =
                typeof data === "boolean"
                  ? String(data ? 1 : 0)
                  : String(data ? 1 : 0);
            } else {
              // For holding and input registers
              if (typeof data === "object") {
                // For JSON data, use a numeric value for Modbus registers
                payload = String(Math.floor(Math.random() * 65535));
              } else if (typeof data === "boolean") {
                payload = String(data ? 1 : 0);
              } else if (typeof data === "string") {
                // For string data, use a register value
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
                `${firstSede.nombre}/1/${registerType}/${registerAddress}`, // Using device ID 1
                payload,
                { qos: 1 },
                () => {
                  resolve();
                }
              );
            });

            batchPromises.push(promise);
            messagesSent++;
            results.modbus.dataTypePerformance[dataType].sent++;
            totalMessageCount++;
          } catch (error) {
            console.error(
              `Error publishing Modbus message with data type ${dataType}:`,
              error
            );
          }
        }

        // Wait for all messages in batch to be published
        await Promise.all(batchPromises);

        batchCount++;
        if (batchCount % 5 === 0) {
          console.log(
            `Modbus: ${messagesSent}/${MESSAGES_PER_DATA_TYPE} ${dataType} messages sent`
          );
        }

        // Add throttling delay between batches
        await new Promise((resolve) => setTimeout(resolve, THROTTLE_DELAY));
      }

      console.log(
        `Completed sending ${messagesSent} Modbus messages with data type: ${dataType}`
      );

      // Wait for all messages to be processed and measure processing time
      const processedCount = await waitForMessageProcessing(
        messagesSent,
        false,
        "modbus",
        dataType
      );

      // Calculate throughput for this data type
      const dataTypeEndTime = performance.now();
      const dataTypeDurationSeconds =
        (dataTypeEndTime - dataTypeStartTime) / 1000;
      const dataTypeThroughput = processedCount / dataTypeDurationSeconds;

      console.log(
        `Modbus ${dataType} throughput: ${dataTypeThroughput.toFixed(
          2
        )} msgs/s ` +
          `(${processedCount} messages in ${dataTypeDurationSeconds.toFixed(
            2
          )}s)`
      );

      // Wait a bit before moving to next data type
      console.log(`Waiting before testing next data type...`);
      await new Promise((resolve) => setTimeout(resolve, 5000));
    }

    console.log(`\nTotal Modbus messages sent: ${totalMessageCount}`);

    // Calculate overall throughput
    const endTime = performance.now();
    const durationSeconds = (endTime - startTime) / 1000;
    const actualThroughput = totalMessageCount / durationSeconds;

    // Add final throughput
    if (results.modbus.throughputSamples.length > 0) {
      results.modbus.throughputSamples.push(actualThroughput);
      results.modbus.throughput = results.modbus.throughputSamples;
    } else {
      results.modbus.throughput.push(actualThroughput);
    }

    console.log(
      `Overall Modbus throughput: ${actualThroughput.toFixed(2)} msgs/s ` +
        `(${totalMessageCount} messages in ${durationSeconds.toFixed(2)}s)`
    );

    // Clean up client
    client.end();
  } catch (error) {
    console.error("Error in Modbus scalability test:", error);
  } finally {
    clearInterval(monitoringInterval);
    console.log(
      `Modbus module scalability test completed with ${totalMessageCount} messages sent.`
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
    // Calculate system latency averages for each data type
    const systemLatency = {};
    for (const dataType of DATA_TYPES) {
      systemLatency[dataType] = calculateStats(
        results[module].systemLatency[dataType]
      );
    }

    // Overall performance metrics
    report.summary[module] = {
      throughput: calculateStats(results[module].throughput),
      cpuUsage: calculateStats(results[module].cpuUsage),
      memoryUsage: calculateStats(results[module].memoryUsage)
    };

    // Per data type metrics
    report.dataTypes[module] = {};
    for (const dataType of DATA_TYPES) {
      // Calculate processing time as the difference between start and end times
      const processingData = results[module].dataTypePerformance[dataType];
      const processingTime =
        processingData.processingEndTime - processingData.processingStartTime;
      const throughput = processingData.processed / (processingTime / 1000); // msgs/sec

      report.dataTypes[module][dataType] = {
        systemLatency: systemLatency[dataType],
        throughput: throughput
      };
    }
  }

  // Print report summary
  console.log("\n\n============= SCALABILITY TEST RESULTS =============");
  console.log(
    `Test Configuration: 1 device sending ${MESSAGES_PER_DATA_TYPE} messages per data type`
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
      "| Tipo de Dato | Latencia (ms)     | Msgs/s        | Min Latencia    | Max Latencia    |"
    );
    console.log(
      "|--------------|-------------------|---------------|-----------------|-----------------|"
    );

    for (const dataType of DATA_TYPES) {
      const stats = report.dataTypes[module][dataType];
      console.log(
        `| ${dataType.padEnd(12)} | ${stats.systemLatency.avg
          .toFixed(2)
          .padEnd(17)} | ${stats.throughput
          .toFixed(2)
          .padEnd(13)} | ${stats.systemLatency.min
          .toFixed(2)
          .padEnd(15)} | ${stats.systemLatency.max.toFixed(2).padEnd(15)} |`
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
Using 1 simulated device
Sending ${MESSAGES_PER_DATA_TYPE} messages per data type
Data types: ${DATA_TYPES.join(", ")}
Total messages per module: ${MESSAGES_PER_DATA_TYPE * DATA_TYPES.length}
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
