provider "google" {
  project = var.project_id
  region  = var.region
  # zone    = var.zone
}

resource "random_id" "suffix" {
  byte_length = 5
}



locals {
  users    = [for u in var.users : ({ name = u.name, password = substr(u.password, 0, 3) == "md5" ? u.password : "md5${md5("${u.password}${u.name}")}" })]
  admins   = [for u in var.users : u.name if lookup(u, "admin", false) == true]
  userlist = templatefile("${path.module}/templates/userlist.txt.tmpl", { users = local.users })
  cloud_config = templatefile(
    "${path.module}/templates/pgbouncer.ini.tmpl",
    {
      db_host            = var.cloud_sql_proxy_host
      db_port            = var.cloud_sql_proxy_port
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
    image                   = "edoburu/pgbouncer:${var.pgbouncer_image_tag}"
    listen_port             = var.listen_port
    config                  = base64encode(local.cloud_config)
    userlist                = base64encode(local.userlist)
    project_id              = var.project_id
    cloud_sql_proxy_image   = var.cloud_sql_proxy_image
    cloud_sql_instance_name = var.database_connection_name
    cloud_sql_proxy_port    = var.cloud_sql_proxy_port
  }
}

data "template_cloudinit_config" "cloud_config" {
  gzip          = false
  base64_encode = false
  part {
    filename     = "cloud-init.yaml"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_config.rendered
  }
}



module "vpc_network" {
  source  = "terraform-google-modules/network/google"
  version = "5.1.0"

  project_id   = var.project_id
  network_name = var.network_name

  subnets = var.subnets

  secondary_ranges = var.secondary_ranges
}

data "google_compute_image" "boot" {
  project = split("/", var.boot_image)[0]
  family  = split("/", var.boot_image)[1]
}


resource "google_compute_instance" "pgbouncer_instance" {
  name         = "pgbouncer-vm"
  machine_type = "n1-standard-1"
  zone         = "us-central1-a"

  metadata = {
    user-data = data.template_cloudinit_config.cloud_config.rendered
  }

  boot_disk {
    initialize_params {
      image = data.google_compute_image.boot.self_link
      size  = "10"
    }
  }



  allow_stopping_for_update = true

  service_account {
    email  = module.cloud_sql_proxy_service_account.email
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
resource "google_compute_firewall" "pgbouncer" {
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

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["pgbouncer"]
}



# Create a service account for the Cloud SQL Proxy using google terraform modules

module "cloud_sql_proxy_service_account" {
  source  = "terraform-google-modules/service-accounts/google"
  version = "3.0.0"

  project_id = var.project_id
  names      = ["cloud-sql-proxy"]
  project_roles = [
    "${var.project_id}=>roles/cloudsql.admin",
  ]
}


# module "db_network" {
#   source  = "terraform-google-modules/network/google"
#   version = "5.1.0"

#   project_id   = var.project_id
#   network_name = var.db_network

#   subnets = var.db_subnets
# }

module "private_service_access" {
  source  = "GoogleCloudPlatform/sql-db/google//modules/private_service_access"
  version = "~>5.0.0"



  project_id  = var.project_id
  vpc_network = data.google_compute_subnetwork.db_subnet.self_link
  depends_on  = [module.vpc_network]
}

data "google_compute_subnetwork" "db_subnet" {
  name   = var.subnets[0].subnet_name
  region = var.region
}


# Create Postgres HA Cloud SQL instance using google terraform modules
module "db" {
  source  = "GoogleCloudPlatform/sql-db/google//modules/postgresql"
  version = "~>5.0.0"

  project_id = var.project_id
  name       = "db-${random_id.suffix.hex}"

  database_version = "POSTGRES_12"
  region           = var.region
  zone             = var.zone
  tier             = "db-f1-micro"

  db_name       = var.db_name
  user_name     = var.db_user
  user_password = var.db_password

  availability_type = "REGIONAL"

  ip_configuration = {
    ipv4_enabled        = false
    private_network     = data.google_compute_subnetwork.db_subnet.self_link
    require_ssl         = false
    authorized_networks = []
  }

  # module_depends_on = [module.private_service_access.peering_completed]
}



