# PgBouncer, CloudSQL Proxy and HammerDB setup for Cloud SQL using Terraform

## Overview

- This module creates a Compute Engine instance running PgBouncer, CloudSQL proxy that sits in front of a Cloud SQL HA PostgreSQL instance and HammerDB for generating the Database load.
- Pgbouncer, CloudSQL proxy and HammerDB are configured to run the Systemd service on startup

/etc/systemd/system/demo.service

```bash
[Unit]
Description=Demo
After=docker.service
Requires=docker.service
[Service]
Type=simple
ExecStart=/run/user/start_all_services.sh
ExecStop=/run/user/stop_all_services.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
```

### Start / Stop the services

```bash
systemctl start demo # This will start all the docker containers
systemctl stop demo  # This will stop and remove all the containers
```

Refer to the [scripts/](./scripts) directory for updating any configuration of the PgBouncer, CloudSQL proxy and HammerDB. All the config files will be copied to the server under this `/run/user` location after deployment.

To update the configuration on the fly, i.e. adding new replica or remove one. You can simply ssh into the machine update the `start_all_services.sh`. Similarly you can update the configurations of PgBouncer, CloudSQL Proxy and HammerDB.

```bash
#!/bin/bash

# Start all services in the correct order
docker network create demo-network

# run the cloud sql proxy docker container
/usr/bin/docker run --name cloudsql-proxy --detach --restart always \
        --network demo-network \
        -p ${cloud_sql_proxy_port}:${cloud_sql_proxy_port} \
        ${cloud_sql_proxy_image} ${cloud_sql_instance_name} ${cloud_sql_replica_name} --address 0.0.0.0 --private-ip

# run the pgbouncer docker container
/usr/bin/docker run \
        --name pgbouncer \
        --restart always \
        --detach \
        --network demo-network \
        -p ${listen_port}:${listen_port} \
        -v /run/user/userlist.txt:/etc/pgbouncer/userlist.txt:ro \
        -v /run/user/pgbouncer.ini:/etc/pgbouncer/pgbouncer.ini:ro \
        ${image}

# run the hammerdb docker container
/usr/bin/docker run -d --name hammerdb \
        --network demo-network \
        -v /run/user/configure-hammerdb.sh:/home/hammerdb/HammerDB-4.7/configure-hammerdb.sh \
        -v /run/user/configure-hammerdb.tcl:/home/hammerdb/HammerDB-4.7/configure-hammerdb.tcl \
        -v /run/user/run_workload.tcl:/home/hammerdb/HammerDB-4.7/run_workload.tcl \
        -v /run/user/run_workload.sh:/home/hammerdb/HammerDB-4.7/run_workload.sh \
        -v /run/user/terminate_active_connections.py:/home/hammerdb/HammerDB-4.7/terminate_active_connections.py \
        -v /run/user/clean_up.sh:/home/hammerdb/HammerDB-4.7/clean_up.sh \
        tpcorg/hammerdb:postgres  
/usr/bin/docker exec -t hammerdb /bin/bash -c "bash /home/hammerdb/HammerDB-4.7/configure-hammerdb.sh"
```

## Configuring PgBouncer

Only a subset of PgBouncer's configuration are exposed as input variables. If you wish to customise PgBouncer further, you're able to provide your own configuration via the `pgbouncer_custom_config` input variable (type `map(string)`). The values from this variable will be added to `pgbouncer.ini`.

The `pgbouncer.ini` template used by this module can be found [here](./templates/pgbouncer.ini.tmpl). Refer to the [official PgBouncer documentation](https://www.pgbouncer.org/config.html) for a full list of configuration options.

## Generating Database traffic using HammerDB

```bash
docker exec -it hammerdb bash # ssh into the docker container
./run_workload.sh # will start generating the database load
```

## Clean up

Once the run_workload.sh script is completed you should clean up the HammerDB using the below command if you're exiting or you want to rerun the workload again.

```bash
./clean_up.sh  # will kill all the db connections and safely delete the db schema
```

## Service Account

A service account with the following roles must be used to provision
the resources of this module:

- `roles/cloudsql.admin`
 Need to give Service Networking api the following permission
- `roles/servicenetworking.serviceAgent`

## APIs

A project with the following APIs enabled must be used to host the
resources of this module:

- `compute.googleapis.com`
- `cloudresourcemanager.googleapis.com`
- `sqladmin.googleapis.com`
- `servicenetworking.googleapis.com`
