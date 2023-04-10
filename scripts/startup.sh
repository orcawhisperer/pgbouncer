# Install Cloud SQL Proxy
    wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O cloud_sql_proxy
    chmod +x cloud_sql_proxy
    mv cloud_sql_proxy /usr/local/bin/

    # Set up environment variables
    export CLOUD_SQL_PROXY=/usr/local/bin/cloud_sql_proxy
    export CLOUD_SQL_INSTANCE=<your-instance-connection-name>