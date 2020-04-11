"use strict";

var nconf = require('nconf');
nconf.file({ file: '/data/http.json' });

////////// HTTP Dependencies //////////////
const express = require('express')
const bodyParser = require('body-parser');

////////// MQTT Dependencies //////////////
const mqtt = require('mqtt')
const client  = mqtt.connect('mqtt://127.0.0.1:1883')
//var DATA = {}

////////////  MODBUS function   /////////////
const modbusSubscribe = require("./modbus").subscribeTopicoModbus,
     sedePuertoConfig = require("./modbus").sedePuertoConfig

////////// MQTT Functions //////////////
client.on('connect', function () {
    console.info("Conectado al broker. Esperando topicos para suscribirse...")
})
    
client.on('message', async function (topic, message) {
    const proTopic = topic.split("/")
    const sede = proTopic[0]
    var data = {}
    proTopic.shift()
    proTopic.reduceRight((prev,cuV,cuI,arreglo)=>{
        var dummy={}
        dummy[cuV]=prev
        if (cuI==0){
            data[cuV]=prev
        }
        return dummy
    },message.toString())
    console.log(`data optenida ${data} para el topico ${topic} con mensaje ${message.toString()}`)
    var actual= nconf.get(sede)
    nconf.set(sede,Object.assign(actual,data))
    return 
})



const initialize= async()=>{
    //await HTTPStorage.init()
    var puerto =  nconf.get("lastUsedHTTPPort")
    console.log("Puerto https",puerto)
    ////////// HTTP Functions //////////////
    var app = express()
    app.use(bodyParser.urlencoded({extended:false}));
    app.use(bodyParser.json());

    app.put('/mqtt/subscribe/:sede',async (req, res)=>{
        console.info("Suscribiendose a la sede: ",req.params.sede)
        client.subscribe(req.params.sede+"/#")
        var sede = express()
        sede.use(bodyParser.urlencoded({extended:false}));
        sede.use(bodyParser.json());
        //Este Topico es sin la sede! ya la sede la se.. 
        //seria plantaBaja-cuarto1-techo-temperatura
        sede.get('/mqtt/get/:topic', async function (req2, res2) {
            var DATA =  nconf.get(req.params.sede)
            const proTopic = req2.params.topic.split("-")
            proTopic.forEach(element => {
                if (DATA[element]){
                    DATA = DATA[element]
                }
            });
            console.info(`Sede: ${req.params.sede}. Transmitiendo data del topico ${req2.params.topic} DATA: ${DATA}`)
            return res2.status(200).send(DATA)
        })
        var servers = nconf.get("servers")
        servers.push(req.params.sede)
        nconf.set("server",servers)
        var puerto1 = nconf.get("lastUsedHTTPPort")
        puerto1+=1
        sede.listen(puerto1, () => {
            console.info(`HTTP sede:${req.params.sede} server escuchando al puerto ${puerto1}`);
        })
        return res.status(201).send("Subscrito satisfactoriamente. escuchando puerto: ",puerto1)
    })

    app.put('/mqtt/modbus/nuevasede/:sede',async function(req,res){
        console.info(`Registrando nueva sede ${req.params.sede} para modbus`)
        const puerto = modbusSubscribe(req.params.sede)
        return res.status(200).json({puerto: puerto})
    })

    app.get('/mqtt/modbus/puertos', function(req,res){
        const response = sedePuertoConfig()
        return res.status(200).json(response)
    })

    // app.post('/mqtt/modbus/reinit',(req,res)=>{
    //     res.status(200).send()
    //     return modbus.initOrReInit()
    // })
    
    app.listen(3000, () => {
        console.info(`HTTP Control server escuchando al puerto 3000`);
    })
    nconf.set("lastUsedHTTPPort","3000")

    var servers = nconf.get("servers")
    servers = servers==undefined ? [] : servers
    if (servers.length>0){
        servers.forEach(async (server)=>{
            console.info("Suscribiendose a la sede: ",server)
            client.subscribe(server+"/#")
            var sede = express()
            sede.use(bodyParser.urlencoded({extended:false}));
            sede.use(bodyParser.json());
            //Este Topico es sin la sede! ya la sede la se.. 
            //seria plantaBaja-cuarto1-techo-temperatura
            sede.get('/mqtt/get/:topic', async function (req2, res2) {
                var DATA = nconf.get(server)
                const proTopic = req2.params.topic.split("-")
                proTopic.forEach(element => {
                    if (DATA[element]){
                        DATA = DATA[element]
                    }
                });
                console.info(`Sede: ${server}. Transmitiendo data del topico ${req2.params.topic} DATA: ${DATA}`)
                return res2.status(200).send(DATA)
            })
            
            var puerto1 = nconf.get("lastUsedHTTPPort")
            puerto1+=1
            nconf.set("lastUsedHTTPPort",puerto1)
            sede.listen(puerto1, () => {
                console.info(`HTTP sede:${server} server escuchando al puerto ${puerto1}`);
            })
        })
    }
}
initialize()
