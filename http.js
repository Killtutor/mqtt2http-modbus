"use strict";
var DATA = {lastUsedHTTPPort:2999}
////////// HTTP Dependencies //////////////
const express = require('express')
const bodyParser = require('body-parser');

////////// MQTT Dependencies //////////////
const mqtt = require('mqtt')

////////////  MODBUS function   /////////////
const modbusSubscribe = require("./modbus").subscribeTopicoModbus,
     sedePuertoConfig = require("./modbus").sedePuertoConfig

const initialize= async()=>{
    ////////// MQTT Functions //////////////
    const client  = mqtt.connect('mqtt://127.0.0.1:1883')
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
        var actual= DATA[sede]
        DATA[sede] = Object.assign(actual,data)
        return 
    })


    //await HTTPStorage.init()
    var puerto =  DATA["lastUsedHTTPPort"]
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
            var data =  DATA[req.params.sede]
            const proTopic = req2.params.topic.split("-")
            proTopic.forEach(element => {
                if (data[element]){
                    data = data[element]
                }
            });
            console.info(`Sede: ${req.params.sede}. Transmitiendo data del topico ${req2.params.topic} DATA: ${data}`)
            return res2.status(200).send(data)
        })
        var servers = DATA["servers"]
        servers.push(req.params.sede)
        DATA["servers"] = servers
        DATA["lastUsedHTTPPort"] = DATA["lastUsedHTTPPort"] +1
        sede.listen(DATA["lastUsedHTTPPort"], () => {
            console.info(`HTTP sede:${req.params.sede} server escuchando al puerto ${DATA["lastUsedHTTPPort"]}`);
        })
        return res.status(201).send("Subscrito satisfactoriamente. escuchando puerto: ",DATA["lastUsedHTTPPort"])
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

    app.listen(3000, () => {
        console.info(`HTTP Control server escuchando al puerto 3000`);
    })

    DATA["lastUsedHTTPPort"] = 3000

    var servers = DATA["servers"]
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
                var data =  DATA[req.params.sede]
                const proTopic = req2.params.topic.split("-")
                proTopic.forEach(element => {
                    if (data[element]){
                        data = data[element]
                    }
                });
                console.info(`Sede: ${req.params.sede}. Transmitiendo data del topico ${req2.params.topic} DATA: ${data}`)
                return res2.status(200).send(data)
            })
            
            DATA["lastUsedHTTPPort"] += 1
            sede.listen(DATA["lastUsedHTTPPort"], () => {
                console.info(`HTTP sede:${server} server escuchando al puerto ${DATA["lastUsedHTTPPort"]}`);
            })
        })
    }
}
initialize()
