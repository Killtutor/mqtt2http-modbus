"use strict";

const { fork } = require("node:child_process");
const procesos = {
  mqttBroker: fork("./broker.js", { silent: false }),
  httpServer: fork("./http.js", { silent: false }),
  modbusSlave: fork("./modbus.js", { silent: false }),
  config: fork("./configTranslator.js", { silent: false })
};
procesos.performance = fork(
  `../tests/performance.js ${procesos.httpServer.pid} ${procesos.modbusSlave.pid}`,
  { silent: false }
);
// procesos.scalability = fork(
//   `../tests/scalability.js ${procesos.httpServer.pid} ${procesos.modbusSlave.pid}`,
//   { silent: false }
// );

process.on("warning", (e) => console.warn(e.stack));
process.on("exit", function () {
  for (var indice in procesos) {
    procesos[indice].exit(1);
  }
});
