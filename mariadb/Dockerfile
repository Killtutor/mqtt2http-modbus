# Usa la imagen base de MariaDB
FROM mariadb:10.5

# Copia el script de configuración SQL al directorio docker-entrypoint-initdb.d
COPY init.sql /docker-entrypoint-initdb.d/
RUN ls -al /docker-entrypoint-initdb.d/

# Exponer el puerto de la base de datos (3306 por defecto)
EXPOSE 3306

# Actualizar lista de paquetes e instalar paquetes necesarios
RUN apt update && apt install -y \
    nano \
    iputils-ping \
    net-tools \
    mariadb-client
