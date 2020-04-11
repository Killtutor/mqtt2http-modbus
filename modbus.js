"use strict";

const Storage = require('node-localstorage').LocalStorage;
var modbusStorage = new Storage('./data/modbus');
//MQTT client
const mqtt = require('mqtt')
const client  = mqtt.connect('mqtt://127.0.0.1:1883')

// Init Function, Runs once on server livespan
const initialize= async()=>{
    //init modbus storage 
    //await modbusStorage.init()

    
    client.on('connect', function () {
        console.info("Modbus Conectado al broker. Subscribite con http para empezar a escuchar")
    })
        
    //formato esperado de topico: sede/RTU#/retype/addr#
    //retype could be input, coil, holding, discrete
    client.on('message', async function (topic, message) {
        const proTopic = topic.split("/")
        const sede = proTopic[0]
        const RTU = parseInt(proTopic[1])
        const retype = proTopic[2]==="input"?"ir":proTopic[2]==="holding"?"hr":proTopic[2]==="discrete"?"dr":"cr"
        const addr = parseInt(proTopic[3])
        const context = message.toString();
        const data = await modbusStorage.getItem(sede)
        data.rtu[RTU][retype][addr] = parseInt(context)
        modbusStorage.setItem(sede, data)
        console.info(`recibi topico ${topic}. sede:${sede}, RTU#${RTU}, register:${proTopic[2]}, direccion: ${addr}, data:${parseInt(context)}`)
    })

    var puerto = await modbusStorage.getItem("lastUsedPort")
    if (!puerto){
        return modbusStorage.setItem("lastUsedPort",8049)
    }else{
        modbusStorage.forEach(async(dato)=>{
            if (dato.key!="lastUsedPort" && dato.key!="lastUsedHTTPPort" && dato.value.hasOwnProperty("puerto")){
                console.log(dato.key)
                initServerTCP(dato.value.nombre,dato.value.puerto)
                client.subscribe(`${dato.value.nombre}/#`) 
            }
        })
    }
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
    await modbusStorage.setItem("lastUsedPort",(parseInt(await modbusStorage.getItem("lastUsedPort"))+1))
    const DATA = {}
    DATA[topico]={nombre:topico,puerto:parseInt(await modbusStorage.getItem("lastUsedPort")),rtu:[]}
    //console.log(DATA)
    DATA[topico].rtu= new Array(256).fill({ir:[0],hr:[0],dr:[0],cr:[]})
    modbusStorage.setItem(topico,DATA[topico])
    initServerTCP(DATA[topico].nombre,DATA[topico].puerto)
    client.subscribe(`${topico}/#`)
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
    modbusStorage.forEach(async (dato)=>{
        retrieve[dato.key]={nombre:dato.value.nombre,puerto:dato.value.puerto}
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
                    const DATA= await modbusStorage.getItem(sede)
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
                    const DATA= await modbusStorage.getItem(sede)
                    return resolve(Number(DATA.rtu[unitID].ir[addr])?Number(DATA.rtu[unitID].ir[addr]):0);
                } catch (error) {resolve(0)
                    return console.error(error)
                }
            })
        },
        getHoldingRegister: async function(addr, unitID) {
            return new Promise(async (resolve)=>{
                try {
                    const DATA= await modbusStorage.getItem(sede)
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
                    const DATA= await modbusStorage.getItem(sede)
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
