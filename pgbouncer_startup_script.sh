# Pgbouncer startup script

# Install pgbouncer

sudo apt-get update
sudo apt-get -y install pgbouncer

# Configure pgbouncer
cat << EOF > /etc/pgbouncer/pgbouncer.ini
[databases]
mydb = host=/cloudsql/${cloud_sql_connection_name} dbname=${db_name} user=${db_user} password=${db_pass}

EOF

# Configure the Cloud SQL proxy
sudo wget -O /cloud_sql_proxy https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64
sudo chmod +x /cloud_sql_proxy
sudo mkdir -p /cloudsql
sudo chown $(whoami) /cloudsql
./cloud_sql_proxy -dir=/cloudsql -instances=${cloud_sql_connection_name}=tcp:5432 &

# Start pgbouncer
sudo systemaaclt enable pgbouncer
sudo systemctl start pgbouncer

