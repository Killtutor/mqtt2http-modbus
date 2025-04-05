"use strict";
var { fork } = require("node:child_process");

// cada proceso se ejecuta en un hilo y manejara 10 dispositivos
var procesos = {
  modbusTest: fork("./modbusTest.js", { silent: false }),
  httpTest: fork("./httpTest.js", { silent: false })
};
process.on("warning", (e) => console.warn(e.stack));
process.on("exit", function () {
  for (var indice in procesos) {
    procesos[indice].exit(1);
  }
});
