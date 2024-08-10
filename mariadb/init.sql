-- Crear la base de datos 'vemetris'
CREATE DATABASE IF NOT EXISTS vemetris;

-- Crear un usuario 'vemetris' y darle privilegios
CREATE USER 'vemetris' IDENTIFIED BY 'vemetris210696';
GRANT ALL PRIVILEGES ON *.* TO 'vemetris'@'%' IDENTIFIED BY 'vemetris210696';
FLUSH PRIVILEGES;
