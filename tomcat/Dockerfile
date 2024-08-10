# Usa la imagen base de Tomcat 8
#FROM tomcat:8
FROM tomcat:8-jre8

# Copia tu carpeta ROOT personalizada al directorio webapps de Tomcat

COPY ./ROOT /usr/local/tomcat/webapps/ROOT
COPY ./env.vemetris /usr/local/tomcat/webapps/ROOT/WEB-INF/classes/env.properties
COPY ./healthCheck.sh /healthCheck.sh
RUN chmod 777 -R /healthCheck.sh
RUN chmod 777 -R /usr/local/tomcat/webapps/ROOT
# RUN chmod 777 -R /usr/local/tomcat/webapps/ScadaBR1.2

# Actualizar lista de paquetes e instalar paquetes necesarios
RUN apt update && apt install -y \
    nano \
    iputils-ping \
    net-tools \
    mariadb-client \
    netcat
