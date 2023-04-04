provider "google" {
  project = var.project_id
  region  = "us-central1"
}

# module "cloudsql_instance" {
#   source = "terraform-google-modules/sql-db/google//modules/postgres"

#   project_id          = var.project_id
#   region              = var.region
#   name                = var.instance_name
#   database_version    = "POSTGRES_13"
#   tier                = "db-n1-standard-2"
#   high_availability   = true
#   create_replica      = true
#   replica_region_list = ["us-east1", "us-west1"]

#   network_name    = module.vpc_network.network_name
#   subnet_name     = module.vpc_network.subnets["us-central1-subnet"].name
#   private_network = true

#   labels = {
#     environment = var.environment
#   }

#   users = [
#     {
#       name     = var.db_username
#       password = var.db_password
#       roles    = ["cloudsqlsuperuser"]
#     }
#   ]
# }

# output "connection_string" {
#   value = module.cloudsql_instance.connection_name
# }

# output "replica_connection_strings" {
#   value = module.cloudsql_instance.replica_connection_names
# }


# module "cloudsql" {
#   source = "terraform-google-modules/cloudsql/google"

#   project_id           = "<your-project-id>"
#   name                 = "my-cloudsql-instance"
#   region               = "us-central1"
#   tier                 = "db-n1-standard-1"
#   database_version     = "POSTGRES_13"
#   authorized_networks  = ["10.0.0.0/16"]
#   backup_configuration = {}

#   ha = true

#   read_replica_zones = [
#     "us-east1-b",
#     "us-west1-a",
#     "asia-east1-a",
#   ]

#   read_replica_zones_fallback = [
#     "us-east4-a",
#     "europe-west3-a",
#     "asia-southeast1-a",
#   ]

#   maintenance_window = {
#     day  = 6
#     hour = 2
#   }

#   backup_window = {
#     start_time = "22:00"
#     end_time   = "02:00"
#   }

# }


# data "cloudsql_database_instance" "primary" {
#   name = module.cloudsql.primary_instance_name
# }

# data "cloudsql_database_instance" "replica" {
#   name = module.cloudsql.replica_instance_name
# }

module "vpc_network" {
  source  = "terraform-google-modules/network/google"
  version = "5.1.0"

  project_id   = "<your-project-id>"
  network_name = "my-custom-vpc"

  subnets = [
    {
      subnet_name           = "us-central1-subnet"
      subnet_ip             = "10.0.1.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = true
    },
    {
      subnet_name           = "us-east1-subnet"
      subnet_ip             = "10.0.2.0/24"
      subnet_region         = "us-east1"
      subnet_private_access = true
    },
    {
      subnet_name           = "us-west1-subnet"
      subnet_ip             = "10.0.3.0/24"
      subnet_region         = "us-west1"
      subnet_private_access = true
    },
  ]

  secondary_ranges = {
    us-central1-subnet = [
      {
        range_name    = "us-central1-subnet"
        ip_cidr_range = "10.0.1.128/25"
      }
    ],
    us-east1-subnet = [
      {
        range_name    = "us-east1-subnet"
        ip_cidr_range = "10.0.2.128/25"
      }
    ],
    us-west1-subnet = [
      {
        range_name    = "us-west1-subnet"
        ip_cidr_range = "10.0.3.128/25"
      }
    ]
  }
}

# data "google_sql_database_instance" "my_instance" {
#   name = "my-cloudsql-instance"
# }

# data "google_sql_database_instances" "name" {

# }


resource "google_compute_instance" "pgbouncer_instance" {
  name         = "pgbouncer-vm"
  machine_type = "n1-standard-1"
  zone         = "us-central1-a"

  metadata = {
    # Install PgBouncer and Cloud SQL Proxy
    "pgbouncer-version"       = "1.15.0"
    "cloud-sql-proxy-version" = "1.28.0"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
      size  = "10"
    }
  }

  metadata_startup_script = <<-SCRIPT
    # Start the Cloud SQL Proxy and connect to the primary CloudSQL instance and read replica
    /cloud_sql_proxy \
      -instances=<INSTANCE_CONNECTION_NAME>=tcp:5432,<READ_REPLICA_CONNECTION_NAME>=tcp:5432 \
      -credential_file=/var/secrets/cloudsql/credentials.json \
      &

    # Start PgBouncer
    pgbouncer /etc/pgbouncer/pgbouncer.ini \
      &

    # Wait for PgBouncer to start up
    sleep 5

    # Create the PgBouncer user database and users
    PGPASSWORD=${var.db_password} psql -h localhost -p 6432 -U postgres -c "CREATE DATABASE ${var.db_name}"
    PGPASSWORD=${var.db_password} psql -h localhost -p 6432 -U postgres -c "CREATE USER ${var.db_user}"
    PGPASSWORD=${var.db_password} psql -h localhost -p 6432 -U postgres -c "ALTER USER ${var.db_user} PASSWORD '${var.db_password}'"
    PGPASSWORD=${var.db_password} psql -h localhost -p 6432 -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${var.db_name} TO ${var.db_user}"

    # Configure PgBouncer
    echo "[databases]" > /etc/pgbouncer/userlist.txt
    echo "<INSTANCE_CONNECTION_NAME>:<DB_NAME>:pgbouncer:<PGBOUNCER_PASSWORD>" >> /etc/pgbouncer/userlist.txt
    echo "<READ_REPLICA_CONNECTION_NAME>:<DB_NAME>:pgbouncer:<PGBOUNCER_PASSWORD>" >> /etc/pgbouncer/userlist.txt
    echo "" >> /etc/pgbouncer/userlist.txt
    echo "[pgbouncer]" > /etc/pgbouncer/pgbouncer.ini
    echo "listen_port = 6432" >> /etc/pgbouncer/pgbouncer.ini
    echo "listen_addr = 0.0.0.0" >> /etc/pgbouncer/pgbouncer.ini
    echo "auth_type = md5" >> /etc/pgbouncer/pgbouncer.ini
    echo "auth_file = /etc/pgbouncer/userlist.txt" >> /etc/pgbouncer/pgbouncer.ini
    echo "default_pool_size = 20" >> /etc/pgbouncer/pgbouncer.ini
    echo "pool_mode = transaction" >> /etc/pgbouncer/pgbouncer.ini
    echo "server_reset_query = DISCARD ALL" >> /etc/pgbouncer/pgbouncer.ini
    echo "server_round_robin = 1" >> /etc/pgbouncer/pgbouncer.ini
    echo "server_idle_timeout = 120" >> /etc/pgbouncer/pgbouncer.ini
    echo "server_lifetime = 600" >> /etc/pgbouncer/pgbouncer.ini
  SCRIPT

  service_account {
    email  = "default"
    scopes = ["cloud-platform"]
  }

  network_interface {
    network = module.vpc_network.network_name

    access_config {
      # Use ephemeral IP address
    }

    subnetwork_project = module.vpc_network.project_id
    subnetwork         = module.vpc_network.subnets["us-central1-subnet"].name
    # subnetwork_ip      = module.vpc_network.subnets["us-central1-subnet"].ip_cidr_range
  }
}





# output "cloudsql_instance_connection_name" {
#   value = module.cloudsql.connection_name
# }
