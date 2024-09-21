const config = require("./config.json");
const mqtt = require("mqtt");
const { setTimeout } = require("timers/promises");

async function runTestData(client) {
  let timeout = 5000;
  let rtus = 10;
  setInterval(() => {
    if (timeout > 1000) {
      timeout -= 100;
      rtus += 10;
      console.log(timeout, rtus, "Timeout,rtus");
    }
  }, 10000);
  await setTimeout(4000);
  for (const sede of config.modbusSedes) {
    try {
      await setTimeout(timeout);
      console.log("🚀 ~ runTestData ~ rtus:", rtus);
      for (let i = 0; i < rtus; i++) {
        console.log("🚀 ~ runTestData ~ i:", i);
        for (let j = 0; j < 50; j++) {
          await setTimeout(Number((Math.random() * 99).toFixed(0)));
          await Promise.all([
            client
              .publishAsync(
                `${sede.nombre}/${i}/coil/${j}`,
                String(Math.random() > 0.5 ? 1 : 0)
              )
              .then((d) => {
                if (d) {
                  console.log(d.reasonCode, d.clean, d.qos, d.cmd, "AQUII");
                }
              }),

            client.publishAsync(
              `${sede.nombre}/${i}/holding/${j}`,
              String(Math.random() * 100)
            )
          ]);
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
        username: config.mqttUser
        // rejectUnauthorized: false,
        // keyPath: "./TLS/client.key",
        // certPath: "./TLS/clientCertificate.pem"
      }
    );
    client.on("connect", function () {
      console.info("TESTING SUITE Conectado al broker");
    });
    // runTestData(client);
    toTheFail(client);
  }
}
