const config = require("./config.json");
const mqtt = require("mqtt");
const { setTimeout } = require("timers/promises");

async function functionalityTest(client) {
  for (const sede of config.modbusSedes) {
    await Promise.all([
      client.publishAsync(`${sede.nombre}/1/coil/0`, String(0)),
      client.publishAsync(`${sede.nombre}/1/coil/1`, String(1)),
      client.publishAsync(`${sede.nombre}/2/coil/0`, "false"),
      client.publishAsync(`${sede.nombre}/2/coil/1`, "true"),
      client.publishAsync(`${sede.nombre}/1/holding/0`, String(1234)),
      client.publishAsync(`${sede.nombre}/1/holding/4`, String(-1234)),
      client.publishAsync(`${sede.nombre}/2/holding/0`, String(12.34)),
      client.publishAsync(`${sede.nombre}/2/holding/4`, String(-12.34)),
      client.publishAsync(
        `${sede.nombre}/1/string/8`,
        "Probando Alphanumericos, en HTTP y MODBUS                                              "
      )
    ]);
  }
}

async function runTestData(client) {
  let timeout = 2000;
  let rtus = 5;
  while (true) {
    await setTimeout(1000);
    for (const sede of config.modbusSedes) {
      for (let i = 1; i < rtus; i++) {
        for (let j = 0; j < 3; j++) {
          await setTimeout(500);
          console.log(
            "Publicando topico: ",
            `${sede.nombre}/${i}/holding/${j}`,
            "valor: "
          );
          console.log(
            "Publicando topico: ",
            `${sede.nombre}/${i}/coil/${j}`,
            "valor: "
          );
          await Promise.all([
            client.publishAsync(
              `${sede.nombre}/${i}/coil/${j}`,
              String(Math.random() > 0.5 ? 1 : 0)
            ),
            client.publishAsync(
              `${sede.nombre}/${i}/holding/${j}`,
              i === 1 && j > 3 ? String(20594) : String(Math.random() * 100)
            )
          ]);
        }
        await client.publishAsync(
          `${sede.nombre}/${i}/string/${3}`,
          "Probando Alphanumerico en Modbus, ESto guarda en HR"
        );
      }
    }
  }
  for (const sede of config.modbusSedes) {
    try {
      await setTimeout(timeout);
      console.log("🚀 ~ runTestData ~ rtus:", rtus);
      for (let i = 0; i < rtus; i++) {
        console.log("🚀 ~ runTestData ~ i:", i);
        for (let j = 0; j < 50; j++) {
          await setTimeout(500);
          console.log(
            "Publicando topico: ",
            `${sede.nombre}/${i}/holding/${j}`,
            "valor: ",
            String(Math.random() * 100)
          );
          await Promise.all([
            client.publishAsync(
              `${sede.nombre}/${i}/coil/${j}`,
              String(Math.random() > 0.5 ? 1 : 0)
            ),

            client.publishAsync(
              `${sede.nombre}/${i}/holding/${j}`,
              String(Math.random() * 100)
            )
          ]);
          console.log("Publicado");
        }
      }
    } catch (error) {
      console.log("🚀 ~ runTestData ~ error:", error);
    }
  }
}

async function toTheFail(client) {
  let initialTimeout = 100;
  let sede = -1;
  let runTest = true;
  let messagesSent = 0;
  let puntosPorSede = 5000;
  while (runTest) {
    sede += 1;
    initialTimeout -= 50;
    console.log(
      "🚀 ~ toTheFail ~ initialTimeout:",
      initialTimeout,
      messagesSent
    );
    if (initialTimeout < 0) {
      initialTimeout = 100;
      puntosPorSede += 500;
      if (puntosPorSede > 10000) {
        runTest = false;
      }
    }
    if (sede > 2) {
      sede = 0;
    }
    for (let i = 0; i < config.modbusSedes[sede].rtus; i++) {
      console.log("🚀 ~ toTheFail ~ i:", i, sede, puntosPorSede);
      console.time("sede");
      await setTimeout(500);
      for (let j = 0; j < puntosPorSede; j++) {
        await client
          .publishAsync(
            `${config.modbusSedes[sede].nombre}/${i}/holding/${j}`,
            String(Math.random() * 100)
          )
          .then((d) => {
            if (d) {
              console.log(d.reasonCode, d.clean, d.qos, d.cmd, "AQUII");
            }
          });
        messagesSent += 1;
      }
      console.timeEnd("sede");
    }
  }
  console.log("🚀 ~ toTheFail ~ messagesSent:", messagesSent);
}

if (require.main === module) {
  if (Boolean(config.testEnabled)) {
    const client = mqtt.connect(
      `mqtt://${process.env.MQTT_HOST || config.mqttHost}:${
        process.env.MQTT_PORT || config.mqttPort
      }`,
      {
        password: config.mqttPass,
        username: config.mqttUser,
        rejectUnauthorized: false
        // keyPath: "./TLS/client.key",
        // certPath: "./TLS/clientCertificate.pem"
      }
    );
    client.on("connect", function () {
      console.info("TESTING SUITE Conectado al broker");
      functionalityTest(client);
    });
    client.on("error", function (error) {
      console.error("TESTING SUITE Error en el broker", error);
    });
    // toTheFail(client);
  }
}
