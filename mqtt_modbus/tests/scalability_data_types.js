/**
 * Scalability Test with Different Data Types
 *
 * Objective: Evaluate gateway performance when handling different data types
 * (integers, decimals, booleans, strings, JSON) with a controlled message load.
 *
 * Configuration: 1 device sending exactly 500 messages for each data type
 * with separate measurements for each data type's performance.
 */

"use strict";

const mqtt = require("mqtt");
const fs = require("fs");
const path = require("path");
const { performance } = require("perf_hooks");
const pidusage = require("pidusage");
const config = require("./config.json");

// Test configuration
const TEST_MODULES = ["http", "modbus"];
const MESSAGES_PER_DATA_TYPE = 500; // Send 500 messages for each data type
const MESSAGE_VERIFICATION_TIMEOUT = 120000; // 2 minutes timeout for message processing verification
const PROCESSING_CHECK_INTERVAL = 3000; // Check processing progress every 3 seconds
const CPU_MEM_SAMPLING_INTERVAL = 500; // Sample CPU and memory every 500ms

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
    dataTypeResults: {}
  },
  modbus: {
    dataTypeResults: {}
  }
};

// Initialize data type performance metrics
DATA_TYPES.forEach((type) => {
  results.http.dataTypeResults[type] = {
    startTime: 0, // When processing started
    endTime: 0, // When processing ended
    messagesSent: 0, // Number of messages sent
    messagesProcessed: 0, // Number of messages processed
    cpuSamples: [], // CPU usage samples during test
    memorySamples: [], // Memory usage samples during test
    latencyMs: 0, // Processing latency in ms
    throughputMsgSec: 0 // Processing throughput in msgs/sec
  };

  results.modbus.dataTypeResults[type] = {
    startTime: 0,
    endTime: 0,
    messagesSent: 0,
    messagesProcessed: 0,
    cpuSamples: [],
    memorySamples: [],
    latencyMs: 0,
    throughputMsgSec: 0
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
async function monitorPerformance(pid, moduleType, dataType) {
  try {
    const stats = await pidusage(pid);
    // Store this sample for the current data type
    if (dataType) {
      results[moduleType].dataTypeResults[dataType].cpuSamples.push(stats.cpu);
      results[moduleType].dataTypeResults[dataType].memorySamples.push(
        stats.memory / 1024 / 1024
      ); // Convert to MB
    }
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
        temperature: parseFloat((15 + Math.random() * 15).toFixed(2))
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

  const maxWaitTime = 180000; // Up to 3 minutes wait time
  const startTime = performance.now();
  let processed = 0;
  let timeWaiting = 0;
  let lastProcessedCount = 0;
  let stagnantCount = 0;

  while (processed < totalSent && timeWaiting < maxWaitTime) {
    processed = await getProcessedMessageCount(isHttp);

    // Record the processed count
    results[moduleType].dataTypeResults[dataType].messagesProcessed = processed;

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

// Start CPU/memory monitoring for a specific data type test
function startCpuMemoryMonitoring(pid, moduleType, dataType) {
  let intervalId = null;

  console.log(
    `Starting CPU/memory monitoring for ${moduleType} - ${dataType}...`
  );

  // Clear previous samples if any
  results[moduleType].dataTypeResults[dataType].cpuSamples = [];
  results[moduleType].dataTypeResults[dataType].memorySamples = [];

  // Start the interval
  intervalId = setInterval(() => {
    monitorPerformance(pid, moduleType, dataType);
  }, CPU_MEM_SAMPLING_INTERVAL);

  return intervalId;
}

// Stop CPU/memory monitoring
function stopCpuMemoryMonitoring(intervalId) {
  if (intervalId) {
    clearInterval(intervalId);
    console.log("CPU/memory monitoring stopped");
  }
}

// Calculate average of an array of numbers
function calculateAverage(array) {
  if (array.length === 0) return 0;
  return array.reduce((sum, value) => sum + value, 0) / array.length;
}

// Test HTTP module with different data types
async function testHttpScalability(httpPid) {
  console.log(
    "Starting HTTP module scalability test with different data types..."
  );

  let totalMessageCount = 0;
  const overallStartTime = performance.now();

  try {
    // Connect a single MQTT client
    const client = await connectMqttClient("http");

    // Process each data type sequentially
    for (const dataType of DATA_TYPES) {
      console.log(`\n===== Testing HTTP with data type: ${dataType} =====`);
      console.log(`Sending ${MESSAGES_PER_DATA_TYPE} HTTP messages...`);

      // Reset counters for this data type test
      await resetMessageCounters(true);

      // Start monitoring for this data type
      const monitoringIntervalId = startCpuMemoryMonitoring(
        httpPid,
        "http",
        dataType
      );

      // Record test start time
      const startTime = performance.now();
      results.http.dataTypeResults[dataType].startTime = startTime;

      let messagesSent = 0;
      let batchCount = 0;

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

      // Store messages sent
      results.http.dataTypeResults[dataType].messagesSent = messagesSent;

      // Wait for all messages to be processed
      const processedCount = await waitForMessageProcessing(
        messagesSent,
        true,
        "http",
        dataType
      );

      // Record end time and calculate metrics
      const endTime = performance.now();
      results.http.dataTypeResults[dataType].endTime = endTime;

      // Calculate latency and throughput
      const latencyMs = endTime - startTime;
      const throughputMsgSec = processedCount / (latencyMs / 1000);

      // Store calculated metrics
      results.http.dataTypeResults[dataType].latencyMs = latencyMs;
      results.http.dataTypeResults[dataType].throughputMsgSec =
        throughputMsgSec;

      console.log(
        `HTTP ${dataType} metrics:
         - Processing time: ${latencyMs.toFixed(2)} ms
         - Throughput: ${throughputMsgSec.toFixed(2)} msgs/s
         - CPU usage (avg): ${calculateAverage(
           results.http.dataTypeResults[dataType].cpuSamples
         ).toFixed(2)}%
         - Memory usage (avg): ${calculateAverage(
           results.http.dataTypeResults[dataType].memorySamples
         ).toFixed(2)} MB`
      );

      // Stop monitoring for this data type
      stopCpuMemoryMonitoring(monitoringIntervalId);

      // Wait a bit before moving to next data type
      console.log(`Waiting before testing next data type...`);
      await new Promise((resolve) => setTimeout(resolve, 5000));
    }

    console.log(`\nTotal HTTP messages sent: ${totalMessageCount}`);

    // Overall time
    const overallEndTime = performance.now();
    const overallDurationSec = (overallEndTime - overallStartTime) / 1000;

    console.log(
      `Overall HTTP test completed in ${overallDurationSec.toFixed(2)} seconds`
    );

    // Clean up client
    client.end();
  } catch (error) {
    console.error("Error in HTTP scalability test:", error);
  } finally {
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

  let totalMessageCount = 0;
  const overallStartTime = performance.now();

  // Find first sede in config for Modbus testing
  const firstSede = config.modbusSedes[0];

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

      // Start monitoring for this data type
      const monitoringIntervalId = startCpuMemoryMonitoring(
        modbusPid,
        "modbus",
        dataType
      );

      // Record test start time
      const startTime = performance.now();
      results.modbus.dataTypeResults[dataType].startTime = startTime;

      let messagesSent = 0;
      let batchCount = 0;
      let registerTypeIndex = 0;

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

      // Store messages sent
      results.modbus.dataTypeResults[dataType].messagesSent = messagesSent;

      // Wait for all messages to be processed
      const processedCount = await waitForMessageProcessing(
        messagesSent,
        false,
        "modbus",
        dataType
      );

      // Record end time and calculate metrics
      const endTime = performance.now();
      results.modbus.dataTypeResults[dataType].endTime = endTime;

      // Calculate latency and throughput
      const latencyMs = endTime - startTime;
      const throughputMsgSec = processedCount / (latencyMs / 1000);

      // Store calculated metrics
      results.modbus.dataTypeResults[dataType].latencyMs = latencyMs;
      results.modbus.dataTypeResults[dataType].throughputMsgSec =
        throughputMsgSec;

      console.log(
        `Modbus ${dataType} metrics:
         - Processing time: ${latencyMs.toFixed(2)} ms
         - Throughput: ${throughputMsgSec.toFixed(2)} msgs/s
         - CPU usage (avg): ${calculateAverage(
           results.modbus.dataTypeResults[dataType].cpuSamples
         ).toFixed(2)}%
         - Memory usage (avg): ${calculateAverage(
           results.modbus.dataTypeResults[dataType].memorySamples
         ).toFixed(2)} MB`
      );

      // Stop monitoring for this data type
      stopCpuMemoryMonitoring(monitoringIntervalId);

      // Wait a bit before moving to next data type
      console.log(`Waiting before testing next data type...`);
      await new Promise((resolve) => setTimeout(resolve, 5000));
    }

    console.log(`\nTotal Modbus messages sent: ${totalMessageCount}`);

    // Overall time
    const overallEndTime = performance.now();
    const overallDurationSec = (overallEndTime - overallStartTime) / 1000;

    console.log(
      `Overall Modbus test completed in ${overallDurationSec.toFixed(
        2
      )} seconds`
    );

    // Clean up client
    client.end();
  } catch (error) {
    console.error("Error in Modbus scalability test:", error);
  } finally {
    console.log(
      `Modbus module scalability test completed with ${totalMessageCount} messages sent.`
    );
  }
}

// Generate the final report
function generateReport() {
  console.log("\n\n============= SCALABILITY TEST RESULTS =============");
  console.log(
    `Test Configuration: 1 device sending ${MESSAGES_PER_DATA_TYPE} messages per data type`
  );
  console.log("====================================================\n");

  // Create report tables for each module
  for (const module of TEST_MODULES) {
    console.log(`\n${module.toUpperCase()} MODULE - DATA TYPE PERFORMANCE:`);
    console.log(
      "-----------------------------------------------------------------------------------"
    );
    console.log(
      "| Tipo de Dato | Latencia (ms) | Msgs/s      | CPU (%)     | Memoria (MB) |"
    );
    console.log(
      "|--------------|---------------|-------------|-------------|--------------|"
    );

    for (const dataType of DATA_TYPES) {
      const metrics = results[module].dataTypeResults[dataType];
      const avgCpu = calculateAverage(metrics.cpuSamples);
      const avgMemory = calculateAverage(metrics.memorySamples);

      console.log(
        `| ${dataType.padEnd(12)} | ${metrics.latencyMs
          .toFixed(2)
          .padEnd(13)} | ${metrics.throughputMsgSec
          .toFixed(2)
          .padEnd(11)} | ${avgCpu.toFixed(2).padEnd(11)} | ${avgMemory
          .toFixed(2)
          .padEnd(12)} |`
      );
    }

    console.log(
      "-----------------------------------------------------------------------------------"
    );
  }

  // Save detailed results to JSON file
  fs.writeFileSync(
    path.join(__dirname, "scalability_results.json"),
    JSON.stringify(results, null, 2)
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
