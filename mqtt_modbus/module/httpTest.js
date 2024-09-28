const config = require("./config.json");
const mqtt = require("mqtt");
const { setTimeout } = require("timers/promises");

// const fs = require("fs");
// const options = {
//   key: fs.readFileSync("./TLS/client.key"),
//   cert: fs.readFileSync("./TLS/clientCertificate.pem")
// };

async function runTestData(params) {
  if (Boolean(config.testEnabled)) {
    const options = {
      port: 8883,
      host: "mqtt.backend.kriollotech.com",
      protocol: "mqtts",
      username: "Vemetris",
      password: "Vemetris"
    };
    const client = mqtt.connect(options);
    client.on("connect", function () {
      console.info("HTTP TESTING SUITE Conectado al broker");
    });

    client.on("error", function (e) {
      console.error(e);
    });

    while (true) {
      await setTimeout(2000);
      for (const device of config.httpRealTime.devices) {
        await setTimeout(1000);
        await Promise.all(
          device.points.map((d) => {
            // console.log("🚀 ~ device.points.map ~ d:", d);
            const random = Math.random();
            console.log(`${device.nombre}/${d.name}`);
            const dataToSend =
              d.type === "binary"
                ? String(random > 0.5)
                : d.type === "alpha"
                ? `Ola K Ase? ${random * 123}`
                : d.type === "multi"
                ? (random * 123456).toFixed(0)
                : String(random * 123456);
            console.log("🚀 ~ device.points.map ~ dataToSend:", dataToSend);
            return client.publishAsync(
              `${device.nombre}/${d.name}`,
              dataToSend
            );
          })
        );
      }
    }
  }
}
(async () => {
  await runTestData();
})();
if (require.main === module) {
  // ran with `node init.js`
  runTestData();
}
