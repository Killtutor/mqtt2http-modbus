const config = require("./config.json");
const { writeFile } = require("fs/promises");

const exportData = { dataSources: [], dataPoints: [] };

const httpTemplates = {
  binary: {
    dataType: "BINARY",
    binary0Value: "",
    parameterName: "binario"
  },
  numeric: {
    dataType: "NUMERIC",
    binary0Value: "",
    parameterName: "numerico"
  },
  alpha: {
    dataType: "ALPHANUMERIC",
    binary0Value: "",
    parameterName: "alpha"
  },
  multi: {
    dataType: "MULTISTATE",
    binary0Value: "",
    parameterName: "multi"
  }
};

// First lets do modbus config
for (const sede of config.modbusSedes) {
  const dataSourceId = `DS_${(Math.random() * 100000).toFixed(0)}`;
  exportData.dataSources.push({
    xid: dataSourceId,
    type: "MODBUS_IP",
    alarmLevels: {
      POINT_WRITE_EXCEPTION: "URGENT",
      DATA_SOURCE_EXCEPTION: "URGENT",
      POINT_READ_EXCEPTION: "URGENT"
    },
    updatePeriodType: sede.refreshRatePeriod,
    transportType: "TCP",
    contiguousBatches: false,
    createSlaveMonitorPoints: false,
    enabled: true,
    encapsulated: false,
    host: "mqtt",
    maxReadBitCount: 2000,
    maxReadRegisterCount: 125,
    maxWriteRegisterCount: 120,
    name: sede.nombre,
    port: sede.port,
    quantize: false,
    retries: 2,
    timeout: 500,
    updatePeriods: sede.refreshRate
  });
  for (let i = 0; i < sede.rtus; i++) {
    exportData.dataPoints.push({
      xid: `DP_${(Math.random() * 100000).toFixed(0)}`,
      loggingType: "NONE",
      intervalLoggingPeriodType: "MINUTES",
      intervalLoggingType: "INSTANT",
      purgeType: "YEARS",
      pointLocator: {
        range: "COIL_STATUS",
        modbusDataType: "BINARY",
        additive: 0.0,
        bit: 0,
        charset: "ASCII",
        multiplier: 1.0,
        offset: i,
        registerCount: 0,
        settableOverride: true,
        slaveId: 1,
        slaveMonitor: false
      },
      eventDetectors: [],
      engineeringUnits: "",
      chartColour: null,
      chartRenderer: null,
      dataSourceXid: dataSourceId,
      defaultCacheSize: 1,
      deviceName: sede.nombre,
      discardExtremeValues: false,
      discardHighLimit: 1.7976931348623157e308,
      discardLowLimit: -1.7976931348623157e308,
      enabled: true,
      intervalLoggingPeriod: 15,
      name: `${sede.nombre}-coils-${i}`,
      purgePeriod: 1,
      textRenderer: {
        type: "PLAIN",
        suffix: ""
      },
      tolerance: 0.0
    });
    exportData.dataPoints.push({
      xid: `DP_${(Math.random() * 100000).toFixed(0)}`,
      loggingType: "NONE",
      intervalLoggingPeriodType: "MINUTES",
      intervalLoggingType: "INSTANT",
      purgeType: "YEARS",
      pointLocator: {
        range: "HOLDING_REGISTER",
        modbusDataType: "TWO_BYTE_INT_SIGNED",
        additive: 0.0,
        bit: 0,
        charset: "ASCII",
        multiplier: 1.0,
        offset: i,
        registerCount: 0,
        settableOverride: true,
        slaveId: 1,
        slaveMonitor: false
      },
      eventDetectors: [],
      engineeringUnits: "",
      chartColour: null,
      chartRenderer: null,
      dataSourceXid: dataSourceId,
      defaultCacheSize: 1,
      deviceName: sede.nombre,
      discardExtremeValues: false,
      discardHighLimit: 1.7976931348623157e308,
      discardLowLimit: -1.7976931348623157e308,
      enabled: true,
      intervalLoggingPeriod: 15,
      name: `${sede.nombre}-holding-${i}`,
      purgePeriod: 1,
      textRenderer: {
        type: "PLAIN",
        suffix: ""
      },
      tolerance: 0.0
    });
  }
}

// Then HTTP Config

for (const http of config.httpRealTime.devices) {
  const dataSourceId = `DS_${(Math.random() * 100000).toFixed(0)}`;
  exportData.dataSources.push({
    xid: dataSourceId,
    type: "HTTP_RECEIVER",
    deviceIdWhiteList: ["mqtt", http.nombre],
    enabled: true,
    ipWhiteList: ["*.*.*.*"],
    name: http.nombre
  });
  for (const point of http.points) {
    exportData.dataPoints.push({
      xid: `DP_${(Math.random() * 100000).toFixed(0)}`,
      dataSourceXid: dataSourceId,
      name: point.name,
      deviceName: http.nombre,
      pointLocator: httpTemplates[point.type],
      loggingType: "NONE",
      intervalLoggingPeriodType: "MINUTES",
      intervalLoggingType: "INSTANT",
      purgeType: "YEARS",
      eventDetectors: [],
      engineeringUnits: "",
      chartColour: null,
      chartRenderer: null,
      defaultCacheSize: 1,
      discardExtremeValues: false,
      discardHighLimit: 1.7976931348623157e308,
      discardLowLimit: -1.7976931348623157e308,
      enabled: true,
      intervalLoggingPeriod: 15,
      purgePeriod: 1,
      textRenderer: {
        type: "PLAIN",
        suffix: ""
      },
      tolerance: 0.0
    });
  }
}

//   Lastly we write the file
writeFile("importThisInVemetris.json", JSON.stringify(exportData));
