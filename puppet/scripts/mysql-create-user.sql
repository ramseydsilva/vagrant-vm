create database if not exists demo_admin;
GRANT ALL PRIVILEGES ON *.* TO demo@'%' IDENTIFIED BY '1abcdefg' with grant option;
grant reload, process on *.* to 'demo'@'%';
FLUSH PRIVILEGES;
