# Docker_Scada_With_MQTT

With this code, you can run vemetris or scada lts with or without traefik, if you are using traefik you no need to worry about certificates or keys to run the MQTT broker over TLS. the system build its own mqtt broker, and send the data published to mqtt throught http or modbus over TCP following the configurations stablished for it.

## Getting started

make sure you have setted these variables in your system in order to build successfully:

- MYSQL_ROOT_PASSWORD
- REDIS_PASSWORD

Decompress your mango automation open source SCADA in the ROOT directory inside tomcat directory, so it looks like this and the following file exists:
./tomcat/ROOT/index.jsp

then your are 1 command away of making the system work for you.

```bash
docker compose  up --build -d
```
