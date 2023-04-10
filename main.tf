provider "google" {
  project = var.project_id
  region  = "us-central1"
}


locals {
  users    = [for u in var.users : ({ name = u.name, password = substr(u.password, 0, 3) == "md5" ? u.password : "md5${md5("${u.password}${u.name}")}" })]
  admins   = [for u in var.users : u.name if lookup(u, "admin", false) == true]
  userlist = templatefile("${path.module}/templates/userlist.txt.tmpl", { users = local.users })
  cloud_config = templatefile(
    "${path.module}/templates/pgbouncer.ini.tmpl",
    {
      db_host            = var.database_host
      db_port            = var.database_port
      listen_port        = var.listen_port
      auth_user          = var.auth_user
      auth_query         = var.auth_query
      default_pool_size  = var.default_pool_size
      max_db_connections = var.max_db_connections
      max_client_conn    = var.max_client_conn
      pool_mode          = var.pool_mode
      admin_users        = join(",", local.admins)
      custom_config      = var.custom_config
    }
  )
}

data "template_file" "cloud_config" {
  template = file("${path.module}/templates/cloud-init.yaml.tmpl")
  vars = {
    image       = "edoburu/pgbouncer:${var.pgbouncer_image_tag}"
    listen_port = var.listen_port
    config      = base64encode(local.cloud_config)
    userlist    = base64encode(local.userlist)
  }
}

data "cloudinit_config" "cloud_config" {
  gzip          = false
  base64_encode = false
  part {
    filename     = "cloud-init.yaml"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_config.rendered
  }
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

  project_id   = var.project_id
  network_name = var.network_name

  subnets = var.subnets

  secondary_ranges = var.secondary_ranges
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
    user-data                 = data.cloudinit_config.cloud_config.rendered
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
      size  = "10"
    }
  }



  allow_stopping_for_update = true

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
    subnetwork         = var.subnets[0].subnet_name
  }

  tags = ["pgbouncer"]

  depends_on = [
    module.vpc_network
  ]

}

// add firewall rule to allow ssh access to the pgbouncer instance
resource "google_compute_firewall" "pgbouncer_ssh" {
  name    = "pgbouncer"
  network = module.vpc_network.network_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  allow {
    protocol = "tcp"
    ports    = ["6432"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["pgbouncer"]
}





# output "cloudsql_instance_connection_name" {
#   value = module.cloudsql.connection_name
# }


