"use strict";

var { fork } = require("node:child_process");

var procesos = {
  mqttBroker: fork("./broker.js", { silent: false }),
  httpServer: fork("./http.js", { silent: false }),
  modbusSlave: fork("./modbus.js", { silent: false }),
  config: fork("./configTranslator.js", { silent: false })
  // modbusTest: fork("./modbusTest.js", { silent: false })
  // httpTest: fork("./httpTest.js", { silent: false })
};
process.on("warning", (e) => console.warn(e.stack));
process.on("exit", function () {
  for (var indice in procesos) {
    procesos[indice].exit(1);
  }
});
