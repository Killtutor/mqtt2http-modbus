// Import statements
const config = require("./config.json");

// Lets run the MQTT broker if the host is localhost in our config
if (
  ["localhost", "127.0.0.1"].includes(process.env.MQTT_HOST || config.mqttHost)
) {
  // The MQTT broker library
  const aedes = require("aedes")();
  const stats = require("aedes-stats");
  stats(aedes);
  // The authentication function
  aedes.authenticate = (client, username, password, callback) => {
    password = Buffer.from(
      password || "Esta no es la Clave",
      "base64"
    ).toString();
    if (
      username === (process.env.MQTT_USER || config.mqttUser) &&
      password === (process.env.MQTT_PASS || config.mqttPass)
    ) {
      return callback(null, true);
    }
    console.log("Authentication failed.");
    return callback(
      new Error("Authentication Failed!! Please enter valid credentials."),
      false
    );
  };
  aedes.on("clientError", (e) => {
    console.log("Client Error", e);
  });
  aedes.on("connectionError", (e) => {
    console.log("connectionError Error", e);
  });
  // The server instance thats going to be handled by aedes handler.
  // This server for normal MQTT protocol
  const server = require("node:net").createServer(aedes.handle);
  // This For MQTT over TLS
  // const server = require("tls").createServer(options, aedes.handle);
  const port = process.env.MQTT_PORT || config.mqttPort;
  server.listen(port, function () {
    console.log("MQTT Broker started and listening on port ", port);
  });
}
