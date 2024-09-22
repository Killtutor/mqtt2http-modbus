// Import statements
const config = require("./config.json");

// Only needed when MQTT over TLS is required in a localhost environment when published trefik handles everything related to ssl
// const fs = require("fs");
// const options = {
//   key: fs.readFileSync("./TLS/brokerKey.pem"),
//   cert: fs.readFileSync("./TLS/brokerCertificate.pem")
// };

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
    console.log("🚀 ~ username:", username);
    password = Buffer.from(password, "base64").toString();
    console.log("🚀 ~ password:", password);
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
  aedes.on("clientError", () => {
    console.log("Client Error");
  });
  aedes.on("connectionError", () => {
    console.log("connectionError Error");
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
