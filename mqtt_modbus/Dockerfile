# Usa la imagen base de MariaDB
FROM node:20.15

# Copia el script de configuración SQL al directorio docker-entrypoint-initdb.d
COPY ./module /mqtt-modbus
COPY ./tests /tests
COPY ./module/config.json /tests/config.json

WORKDIR /tests

RUN yarn install

WORKDIR /mqtt-modbus

# Actualizar lista de paquetes e instalar paquetes necesarios
RUN yarn install

CMD ["yarn", "start"]
