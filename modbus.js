"use strict";
//MQTT client
const mqtt = require('mqtt')
var client= mqtt.connect('mqtt://127.0.0.1:1883')
var DATA ={"lastUsedPort":8049}
const fs = require("fs")
//Conectandome al Broker
    
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
        const data = DATA[sede]
        data.rtu[RTU][retype][addr] = parseInt(context)
        DATA[sede]= data
	    console.info(`recibi topico ${topic}. sede:${sede}, RTU#${RTU}, register:${proTopic[2]}, direccion: ${addr}, data:${parseInt(context)}`)
    })
// Init Function, Runs once on server livespan
const initialize= ()=>{
    

    DATA = JSON.parse(fs.readFileSync("./data/modbus.json"))

    var puerto = DATA["lastUsedPort"]
    if (!puerto){
        DATA["lastUsedPort"]=8049
    }else{
        Object.keys(DATA).forEach((key)=>{
            if (key!="lastUsedPort" && key!="lastUsedHTTPPort" && DATA[key].hasOwnProperty("puerto")){
                console.log(key)
                initServerTCP(DATA[key].nombre,DATA[key].puerto)
                client.subscribe(`${DATA[key].nombre}/#`) 
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
exports.subscribeTopicoModbus= (topico)=>{
    //from DATA to modbusStorage Update
    DATA["lastUsedPort"]=(parseInt(DATA["lastUsedPort"])+1)
    DATA[topico]={nombre:topico,puerto:parseInt(DATA["lastUsedPort"]),rtu:[]}
    DATA[topico].rtu= new Array(256).fill({ir:[],hr:[],dr:[],cr:[]})
    initServerTCP(DATA[topico].nombre,DATA[topico].puerto)
    client.subscribe(`${topico}/#`)
    fs.writeFile("./data/modbus.json",JSON.stringify(DATA),(error)=>{
        if(error){return console.error(`Error guardando archivo, ${error}`)}
        console.log("guardado exitoso")
    })
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
    var modbusStorage = DATA
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
                    console.log("Consultando CoilRegister, Dirección: ",addr," Esclavo:",unitID," resultado:",DATA[sede].rtu[unitID].ir[addr])
                    return resolve(DATA[sede].rtu[unitID].cr[addr]?true:false)
                } catch (error) {resolve(false)
                    console.error(error)
                }
            })
        },
        getInputRegister: function(addr, unitID) {
            return new Promise(async (resolve)=>{
                try {
                    console.log("Consultando inputRegister, Dirección: ",addr," Esclavo:",unitID," resultado:", DATA[sede].rtu[unitID].ir[addr])
                    return resolve(Number(DATA[sede].rtu[unitID].ir[addr])?Number(DATA[sede].rtu[unitID].ir[addr]):0);
                } catch (error) {resolve(0)
                    return console.error(error)
                }
            })
        },
        getHoldingRegister: async function(addr, unitID) {
            return new Promise(async (resolve)=>{
                try {
                    console.log("Consultando holdingRegister, Dirección: ",addr," Esclavo:",unitID," resultado:",DATA[sede].rtu[unitID].ir[addr])
                    return resolve(Number(DATA[sede].rtu[unitID].hr[addr])?Number(DATA[sede].rtu[unitID].hr[addr]):0);
                } catch (error) {
                    resolve(0)
                    return console.error(error)
                }
            })
        },
        getDiscreteInput: async function(addr, unitID) {
            return new Promise(async (resolve)=>{
                try {
                    console.log("Consultando coilRegister, Dirección: ",addr," Esclavo:",unitID," resultado:",DATA[sede].rtu[unitID].ir[addr])
                    return resolve(DATA[sede].rtu[unitID].dr[addr]?true:false);
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
        console.log(`initialized sede ${sede} en servidor modbus://0.0.0.0:${puerto}, espero topico de la forma ${sede}/RTU#/retype/addr#`);
    });
    
    serverTCP.on("socketError", function(err) {
        console.error(err);
        serverTCP.close(closed);
    });
}
