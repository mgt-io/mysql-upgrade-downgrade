#!/bin/bash
MYSQL_ROOT_PASSWORD=$(clpctl db:show:master-credentials | grep Password | awk '{print $4}')
mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD -e "SELECT 1" > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "MySQL connection failed."
  exit 1
fi
NUMBER_OF_SITES=$(sqlite3 /home/clp/htdocs/app/data/db.sq3 "SELECT COUNT(*) FROM site;")
if [ "$NUMBER_OF_SITES" -gt 0 ]; then
  echo "MySQL 8.4 cannot be installed when sites are present." >&2
  exit 1
fi
rm -f /etc/apt/sources.list.d/percona-mysql.list
apt update
DEBIAN_FRONTEND=noninteractive apt -y --purge remove percona-server-server
rm -rf /home/mysql
curl -o /tmp/percona-release_latest.generic_all.deb https://repo.percona.com/apt/percona-release_latest.generic_all.deb
dpkg -i /tmp/percona-release_latest.generic_all.deb
percona-release enable-only ps-84-lts release
percona-release enable tools release
apt -y update
DEBIAN_FRONTEND=noninteractive apt -y install percona-server-server
rm -f /tmp/percona-release_latest.generic_all.deb
systemctl stop mysql
mv /var/lib/mysql /home/mysql/
curl https://gist.githubusercontent.com/swieczorek/080897dfcadba18997874380f8cf1794/raw/a9518bd709058a999a504e0e458cef49de64d1c0/percona-mysql-8.4-config > /etc/mysql/mysql.conf.d/mysqld.cnf
systemctl restart mysql
mysqladmin -u root password $MYSQL_ROOT_PASSWORD
read -r -d '' SQL_CONFIG <<EOD
DROP USER 'root'@'localhost';
CREATE USER 'root'@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOD
mysql -uroot -p$MYSQL_ROOT_PASSWORD mysql -e "$SQL_CONFIG"
systemctl enable mysql
sqlite3 /home/clp/htdocs/app/data/db.sq3 "UPDATE database_server SET version = '8.4' WHERE host = '127.0.0.1';"