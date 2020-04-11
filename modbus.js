"use strict";
var nconf = require('nconf');
nconf.file({ file: './data/modbus.json' });

//MQTT client
const mqtt = require('mqtt')
const client  = mqtt.connect('mqtt://127.0.0.1:1883')

client.on('connect', function () {
        console.info("Modbus Conectado al broker. Subscribite con http para empezar a escuchar")
    })
        
    //formato esperado de topico: sede/RTU#/retype/addr#
    //retype could be input, coil, holding, discrete
client.on('message', function (topic, message){
	console.log("Mensaje Recibido")
        const proTopic = topic.split("/")
        const sede = proTopic[0]
        const RTU = parseInt(proTopic[1])
        const retype = proTopic[2]==="input"?"ir":proTopic[2]==="holding"?"hr":proTopic[2]==="discrete"?"dr":"cr"
        const addr = parseInt(proTopic[3])
        const context = message.toString();
        const data = nconf.get(sede)
        data.rtu[RTU][retype][addr] = parseInt(context)
        nconf.set(sede, data)
	nconf.save()
        console.info(`recibi topico ${topic}. sede:${sede}, RTU#${RTU}, register:${proTopic[2]}, direccion: ${addr}, data:${parseInt(context)}`)
    })
// Init Function, Runs once on server livespan
const initialize= ()=>{
    //init modbus storage 
    //await modbusStorage.init()

    var puerto = nconf.get("lastUsedPort")
    if (!puerto){
        console.log("setting lastusedport to ", 8049)
        nconf.set("lastUsedPort",8049)
        console.log("result ", nconf.get("lastUsedPort"))
    }else{
        var modbusStorage = nconf.get()
        Object.keys(modbusStorage).forEach((key)=>{
            if (key!="lastUsedPort" && key!="lastUsedHTTPPort" && modbusStorage[key].hasOwnProperty("puerto")){
                console.log(key)
                initServerTCP(modbusStorage[key].nombre,modbusStorage[key].puerto)
                client.subscribe(`${modbusStorage[key].nombre}/#`) 
            }
        })
    }
    nconf.save()
}
if (!module.parent) {
    // ran with `node init.js`
   initialize()
}
//exports.initOrReInit = initialize
//En este objeto se guardará toda la info necesaria (sera el buffer de nuestro gateway mqtt-modbus)
//var DATA = {lastUsedPort:8049}
//ejplo objetio dentro de data
//ejemplo={nombre:"ejemplo",puerto:"8020",rtu:[{ir:[],dr:[],hr:[]},{}]}


/////////////////////////////////////////////////////////////////////
/////////////           Aqui comienza Modbus              ///////////
/////////////////////////////////////////////////////////////////////
/**
 * subscribe al servidor modbus a un topico(sede) en especifico
 *
 * @param sede - Objeto Sede el cual usara para devolver la data
 * @returns integer devuelve el puerto q se creo para esa sede 
 * @public
 */
exports.subscribeTopicoModbus= async (topico)=>{
    //from DATA to modbusStorage Update
    nconf.set("lastUsedPort",(parseInt(nconf.get("lastUsedPort"))+1))
    const DATA = {}
    DATA[topico]={nombre:topico,puerto:parseInt(nconf.get("lastUsedPort")),rtu:[]}
    DATA[topico].rtu= new Array(256).fill({ir:[0],hr:[0],dr:[0],cr:[]})
    nconf.set(topico,DATA[topico])
    initServerTCP(DATA[topico].nombre,DATA[topico].puerto)
    client.subscribe(`${topico}/#`)
    nconf.save()
    return DATA[topico].puerto
}

/**
 * devuelve la data de sedes y puertos
 *
 * @returns array diferentes sedes con sus puertos asignados
 * @public
 */
exports.sedePuertoConfig=()=>{
    var retrieve= {}
    var modbusStorage = nconf.get()
    Object.keys(modbusStorage).forEach((key)=>{
        if (key!="lastUsedPort" && key!="lastUsedHTTPPort" && modbusStorage[key].hasOwnProperty("puerto")){
           retrieve[key]=modbusStorage[key]
        }
    })
    return retrieve
}


/**
 * Inicia el servidor TCP-Modbus para una sede DADA
 *
 * @param sede - Objeto Sede el cual usara para devolver la data
 * @private
 */
function initServerTCP(sede,puerto){
   // create an empty modbus client
    var ModbusRTU = require("modbus-serial");
    var vector = {
        setRegister:function (addr, value, unitID){
            client.publish(`${sede}/${unitID}/setcoil/${addr}`,value)
            console.log("Publicando setRegister Message, Dirección: ",addr," Esclavo:",unitID," resultado:",value)
        },
        setCoil:function(addr,state, unitID) {
            client.publish(`${sede}/${unitID}/setcoil/${addr}`,state)
            console.log("Publicando setcoil Message, Dirección: ",addr," Esclavo:",unitID," resultado:",state)
        },
        getCoil: function(addr, unitID) {
            return new Promise(async (resolve)=>{
                try {
                    const DATA= nconf.get(sede)
                    console.log("Consultando CoilRegister, Dirección: ",addr," Esclavo:",unitID," resultado:",DATA.rtu[unitID].ir[addr])
                    return resolve(DATA.rtu[unitID].cr[addr]?true:false)
                } catch (error) {resolve(false)
                    console.error(error)
                }
            })
        },
        getInputRegister: function(addr, unitID) {
            return new Promise(async (resolve)=>{
                try {
                    console.log("Consultando inputRegister, Dirección: ",addr," Esclavo:",unitID," resultado:")
                    const DATA= nconf.get(sede)
                    return resolve(Number(DATA.rtu[unitID].ir[addr])?Number(DATA.rtu[unitID].ir[addr]):0);
                } catch (error) {resolve(0)
                    return console.error(error)
                }
            })
        },
        getHoldingRegister: async function(addr, unitID) {
            return new Promise(async (resolve)=>{
                try {
                    const DATA= nconf.get(sede)
                    console.log("Consultando holdingRegister, Dirección: ",addr," Esclavo:",unitID," resultado:",DATA.rtu[unitID].ir[addr])
                    return resolve(Number(DATA.rtu[unitID].hr[addr])?Number(DATA.rtu[unitID].hr[addr]):0);
                } catch (error) {
                    resolve(0)
                    return console.error(error)
                }
            })
        },
        getDiscreteInput: async function(addr, unitID) {
            return new Promise(async (resolve)=>{
                try {
                    const DATA= nconf.get(sede)
                    console.log("Consultando coilRegister, Dirección: ",addr," Esclavo:",unitID," resultado:",DATA.rtu[unitID].ir[addr])
                    return resolve(DATA.rtu[unitID].dr[addr]?true:false);
                } catch (error) {
                    resolve(false)
                    return console.error(error)
                }
            })
        }
    };
    // set the server to answer for modbus requests
    var serverTCP = new ModbusRTU.ServerTCP(vector, { host: "0.0.0.0", port:puerto, debug: true });
    serverTCP.on("initialized", function() {
        console.log(`initialized sede ${sede} en servidor modbus://0.0.0.0:${puerto}, espero topico de la forma sede/RTU#/retype/addr#`);
    });
    
    serverTCP.on("socketError", function(err) {
        console.error(err);
        serverTCP.close(closed);
    });
}
