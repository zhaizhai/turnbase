DROP USER ''@'localhost'; -- works around a bug
FLUSH PRIVILEGES;
CREATE USER ''@'localhost' IDENTIFIED WITH mysql_native_password BY '';;
CREATE DATABASE IF NOT EXISTS turnbase;
GRANT ALL ON turnbase.* TO ''@'localhost';
