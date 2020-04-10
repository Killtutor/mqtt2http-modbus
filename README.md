# mqtt2http-modbus

mqtt2http-modbus is a software gateway to translate the MQTT protocol to HTTP and modbus over TCP

## Installation

the easiest way of install is  installing nvm, then install node v11, then install the dependencies

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
nvm install v11
npm install
```

## Usage

Run the server is easy, just node init.js and yo're done!
```bash
node init.js
```

this will be the console log 

```bash
MQTT Broker started and listening on port  1883
HTTP Control server escuchando al puerto 3000
Conectado al broker. Esperando topicos para suscribirse...
Modbus Conectado al broker. Subscribite con http para empezar a escuchar
```
there's no modbus slave or http server to interrogate about a topic, but you could send an http request to make a modbus slave and to start listening


## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.

## License
[MIT](https://choosealicense.com/licenses/mit/)
