# MQTT-HTTP and MQTT-Modbus Performance Tests

This directory contains test scripts for evaluating the performance and scalability of the MQTT-HTTP bridge and MQTT-Modbus modules.

## Test Types

### Performance Test

Measures the following metrics for both HTTP and Modbus modules:

- Latency (ms)
- Throughput (messages/s)
- CPU Usage (%)
- Memory Usage (MB)

Results include average, minimum, maximum, and standard deviation values for each metric.

### Scalability Test

Tests how the system performs with increasing device loads:

- 5 devices
- 20 devices
- 100 devices
- 1000 devices

For each device count, the test measures:

- Average Latency (ms)
- Average Throughput (messages/s)
- Average CPU Usage (%)
- Average Memory Usage (MB)

## Prerequisites

Before running the tests, make sure you have:

1. An MQTT broker running (as configured in the config.json file)
2. For HTTP tests: A mock HTTP server or the real HTTP endpoint (default config uses a local endpoint)
3. For Modbus tests: The Modbus TCP server is running

## Installation

Install the test dependencies:

```bash
cd mqtt2http-modbus/mqtt_modbus/tests
npm install
```

## Running the Tests

### Performance Tests

To run only the performance tests:

```bash
npm run performance
```

This will generate:

- Console output with performance metrics
- A `performance_results.json` file with detailed results

### Scalability Tests

To run only the scalability tests:

```bash
npm run scalability
```

This will generate:

- Console output with scalability metrics for different device counts
- A `scalability_results.json` file with detailed results

### Run All Tests

To run both performance and scalability tests:

```bash
npm test
```

## Customizing Tests

You can customize the test configuration by modifying the constants at the top of each test file:

- `TEST_DURATION`: Duration of each test in milliseconds
- `MESSAGE_INTERVAL`: Time between message sends in milliseconds
- `DEVICE_COUNTS`: (for scalability test) The number of simulated devices to test
- `SAMPLE_INTERVAL`: Interval for sampling CPU and memory usage

## Interpreting Results

Test results will fill in the tables as shown in the project documentation:

1. Performance Test Table (Tabla 6.2):

   - Metrics for Latency, Throughput, CPU Usage, and Memory Usage
   - Values include Average, Minimum, Maximum, and Standard Deviation

2. Scalability Test Table (Tabla 6.3):
   - Metrics for each device count (5, 20, 100, 1000)
   - Values include Average Latency, Average Throughput, Average CPU Usage, and Average Memory Usage
