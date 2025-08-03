# Docker Scada con MQTT

Este proyecto permite desplegar un sistema SCADA (Vemetris o ScadaLTS) junto con un broker MQTT y un servicio de integración que expone los datos a través de HTTP y Modbus TCP. El sistema está diseñado para ser desplegado utilizando Docker y Docker Compose, con la opción de usar Traefik como reverse proxy para la gestión de certificados SSL/TLS de forma automática.

## Características

- **Broker MQTT:** Incluye un broker MQTT propio para la comunicación en tiempo real con dispositivos IoT.
- **Integración de datos:** Un servicio desarrollado en Node.js (`mqtt_modbus`) se suscribe a los tópicos MQTT y expone los datos a través de:
  - Una API RESTful (`httpRealTime`).
  - Múltiples esclavos Modbus TCP (`modbusSedes`).
- **Flexibilidad de despliegue:** Permite elegir entre dos sistemas SCADA:
  - **Vemetris:** La opción por defecto.
  - **ScadaLTS:** Una alternativa de código abierto.
- **Gestión de red con Traefik:** Soporte opcional para Traefik para gestionar el enrutamiento y la seguridad con SSL/TLS.

## Requisitos Previos

Antes de iniciar el sistema, asegúrate de tener las siguientes herramientas instaladas:

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

Además, necesitas configurar las siguientes variables de entorno en tu sistema:

- `MYSQL_ROOT_PASSWORD`: Contraseña para el usuario `root` de la base de datos MariaDB.
- `REDIS_PASSWORD`: Contraseña para la instancia de Redis.

## Configuración del Proyecto

La configuración principal del servicio de integración se encuentra en el archivo `mqtt2http-modbus/mqtt_modbus/module/config.json`. Este archivo es crucial para definir cómo los datos MQTT se transforman y exponen.

```json
{
  "mqttPort": 1883,
  "mqttHost": "127.0.0.1",
  "mqttUser": "Vemetris",
  "mqttPass": "Vemetris",
  "redisUser": "Vemetris",
  "redisPass": "Vemetris",
  "redisUrl": "redis://redis:6379",
  "testEnabled": false,
  "httpRealTime": {
    "port": 3001,
    "devices": [
      {
        "nombre": "EIE_SEDE1_http",
        "points": [
          { "type": "binary", "name": "binario" },
          { "type": "numeric", "name": "numerico" }
        ]
      }
    ]
  },
  "modbusSedes": [
    {
      "nombre": "EIE_SEDE1_modbus",
      "port": 8033,
      "rtus": 10,
      "refreshRatePeriod": "SECONDS",
      "refreshRate": 5
    }
  ]
}
```

### Sección `httpRealTime`

Esta sección configura el servidor HTTP que expone los datos en tiempo real.

- `port`: El puerto en el que correrá el servidor HTTP.
- `devices`: Un array de dispositivos. Cada dispositivo tiene:
  - `nombre`: Un nombre único para el dispositivo. Los datos de este dispositivo estarán disponibles bajo un tópico MQTT específico (`/Vemetris/+/+/EIE_SEDE1_http/#`).
  - `points`: Un array de puntos de datos. Cada punto tiene:
    - `type`: El tipo de dato (`binary`, `numeric`, `alpha`, `multi`).
    - `name`: El nombre del punto de datos.

### Sección `modbusSedes`

Esta sección configura los esclavos Modbus TCP.

- `nombre`: Un nombre único para la sede o esclavo Modbus. Al igual que con `httpRealTime`, esto se usa para determinar el tópico MQTT a escuchar.
- `port`: El puerto TCP para el esclavo Modbus.
- `rtus`: El número de unidades RTU (Remote Terminal Units) disponibles.
- `refreshRatePeriod`: La unidad de tiempo para la tasa de refresco (`SECONDS`, `MINUTES`, etc.).
- `refreshRate`: La frecuencia con la que se actualizan los datos.

## Despliegue

El proyecto ofrece diferentes archivos `docker-compose` para adaptarse a tus necesidades.

### Opción 1: Vemetris con Traefik (Recomendado)

Esta es la configuración más completa y recomendada. Utiliza Traefik para gestionar el acceso a los servicios y la seguridad.

1.  **Crear la red de Traefik:**
    ```bash
    docker network create traefik-net
    ```
2.  **Iniciar Traefik:**
    ```bash
    docker compose -f docker-compose-traefik.yml up -d
    ```
3.  **Iniciar la aplicación:**
    Asegúrate de haber descomprimido tu SCADA en el directorio `./tomcat/ROOT/` de forma que el archivo `./tomcat/ROOT/index.jsp` exista.
    ```bash
    docker compose -f docker-compose.yml up --build -d
    ```

### Opción 2: Vemetris sin Traefik

Si no deseas utilizar Traefik, puedes ejecutar Vemetris directamente.

1.  **Modificar `docker-compose.yml`:**
    Comenta o elimina la sección `networks` de cada servicio y la definición de la red `traefik-net` al final del archivo.
2.  **Iniciar la aplicación:**
    ```bash
    docker compose -f docker-compose.yml up --build -d
    ```

### Opción 3: ScadaLTS

Si prefieres usar ScadaLTS en lugar de Vemetris.

1.  **Iniciar la aplicación:**
    ```bash
    docker compose -f docker-compose-lts.yml up --build -d
    ```

## Estructura de Tópicos MQTT

El servicio `mqtt_modbus` espera una estructura de tópicos específica para procesar los mensajes correctamente. La estructura general es:

`/{sede}/{rtu}/{type}/{addr}` MODBUS
`/{sede}/{param}` HTTP

- `Sede`: Nombre de la sede, debe coincidir con el `nombre` de un dispositivo en `httpRealTime` o `modbusSedes`.
- `rtu`: id de la rtu modbus que desea consultar.
- `type`: tipo de dato modbus (`input`,`holding`,`discrete`,`coil`,`string`)
- `addr`: direccion de memoria modbus (posicion)
- `param`: nombre del parametro a enviar por http
