const config = require("./config.json");
const mqtt = require("mqtt");
const { setTimeout } = require("timers/promises");

async function runTestData(params) {
  if (Boolean(config.testEnabled)) {
    const client = mqtt.connect(
      `mqtts://${config.mqttHost}:${config.mqttPort}`,
      {
        password: config.mqttPass,
        username: config.mqttUser,
        rejectUnauthorized: false,
        keyPath: "./TLS/client.key",
        certPath: "./TLS/clientCertificate.pem"
      }
    );
    client.on("connect", function () {
      console.info("TESTING SUITE Conectado al broker");
    });

    await setTimeout(4000);
    for (const sede of config.modbusSedes) {
      await setTimeout(1000);
      for (let i = 0; i < 10; i++) {
        for (let j = 0; j < 10; j++) {
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
        }
      }
    }
  }
}

if (require.main === module) {
  // ran with `node init.js`
  runTestData();
}
