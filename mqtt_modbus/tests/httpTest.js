const config = require("./config.json");
const mqtt = require("mqtt");
const { setTimeout } = require("timers/promises");

async function functionalityTest(client) {
  return Promise.allSettled([
    client.publishAsync(`EIE_SEDE1_http/boolean0`, "0"),
    client.publishAsync(`EIE_SEDE1_http/boolean1`, "1"),
    client.publishAsync(`EIE_SEDE1_http/booleanf`, "false"),
    client.publishAsync(`EIE_SEDE1_http/booleanT`, "true"),
    client.publishAsync(`EIE_SEDE1_http/integerP`, "1234"),
    client.publishAsync(`EIE_SEDE1_http/integerN`, "-1234"),
    client.publishAsync(`EIE_SEDE1_http/floatP`, "12.34"),
    client.publishAsync(`EIE_SEDE1_http/floatN`, "-12.34"),
    client.publishAsync(
      `EIE_SEDE1_http/string0`,
      "Probando Alphanumericos, en HTTP y MODBUS"
    ),
    client.publishAsync(
      `EIE_SEDE1_http/string1`,
      JSON.stringify({
        temp: 15,
        presion: 1.5,
        humedad: 0.5
      })
    )
  ]);

  for (const device of config.httpRealTime.devices) {
    await setTimeout(1000);
    await Promise.all(
      device.points.map((d) =>
        client.publishAsync(`${device.nombre}/${d.name}`, "1")
      )
    );
  }
}

async function runTestData(client) {
  if (Boolean(config.testEnabled)) {
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
                ? `Probando Variable Alphanumerica ${random * 123}`
                : d.type === "multi"
                ? (random * 123456).toFixed(0)
                : random > 0.5
                ? String(random * 123456)
                : String((random * 9876543).toFixed(0));
            console.log(
              "🚀 ~ device.points.map ~ dataToSend:",
              dataToSend,
              "topic:",
              `${device.nombre}/${d.name}`
            );
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
// (async () => {
//   await runTestData();
// })();

if (require.main === module) {
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
    functionalityTest(client);
  });

  client.on("error", function (e) {
    console.error(e);
  });
}
