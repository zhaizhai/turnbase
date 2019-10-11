DROP USER ''@'localhost'; -- works around a bug
FLUSH PRIVILEGES;
CREATE USER ''@'localhost';
CREATE DATABASE IF NOT EXISTS turnbase;
GRANT ALL ON turnbase.* TO ''@'localhost';
