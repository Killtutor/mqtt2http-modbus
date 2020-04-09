'use strict';

var child = require('child_process');

var procesos = {
    "mqttBroker": child.fork('./broker.js'),
    "httpServer": child.fork('./http.js')
    //"modbusSlave": child.fork('./modbus.js')
};
process.on('warning', e => console.warn(e.stack));
process.on('exit', function() {
    for (var indice in procesos) {
        procesos[indice].exit(1);
    }
});