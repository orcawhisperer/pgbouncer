resource "random_id" "suffix" {
  byte_length = 5
}

locals {
  users    = [for u in var.users : ({ name = u.name, password = u.password })]
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

  configure_hammerdb = templatefile("${path.module}/scripts/configure_hammerdb.sh.tmpl", {})
  configure_hammerdb_tcl = templatefile("${path.module}/scripts/configure_hammerdb.tcl.tmpl", {
    pgbouncer_host = var.pgbouncer_host
    pgbouncer_port = var.listen_port
    db_user        = var.db_user
    db_password    = var.db_password
    hammerdb_user  = var.db_user
    hammerdb_pass  = var.db_password
  })
  run_workload     = templatefile("${path.module}/scripts/run_workload.sh.tmpl", {})
  run_workload_tcl = templatefile("${path.module}/scripts/run_workload.tcl.tmpl", {})

  start_all_services = templatefile("${path.module}/scripts/start_all_services.sh.tmpl", {
    cloud_sql_proxy_port    = var.cloud_sql_proxy_port
    listen_port             = var.listen_port
    cloud_sql_instance_name = module.db.instance_connection_name
    cloud_sql_replica_name  = module.db.replicas_instance_connection_names[0]
    cloud_sql_proxy_image   = var.cloud_sql_proxy_image
    image                   = "edoburu/pgbouncer:${var.pgbouncer_image_tag}"
  })

  stop_all_services = templatefile("${path.module}/scripts/stop_all_services.sh.tmpl", {})

  terminate_active_connections = templatefile("${path.module}/scripts/terminate_active_connections.py.tmpl", {})

  clean_up = templatefile("${path.module}/scripts/clean_up.sh.tmpl", {})

  read_replica_ip_configuration = {
    ipv4_enabled       = false
    require_ssl        = false
    private_network    = module.vpc_network.network_self_link
    allocated_ip_range = null
    authorized_networks = [
      {
        name  = "${var.project_id}-cidr"
        value = module.vpc_network.subnets[keys(module.vpc_network.subnets)[0]].ip_cidr_range
      }
    ]
  }
}

data "template_file" "cloud_config" {
  template = file("${path.module}/templates/cloud-init.yaml.tmpl")
  vars = {
    image                        = "edoburu/pgbouncer:${var.pgbouncer_image_tag}"
    listen_port                  = var.listen_port
    config                       = base64encode(local.cloud_config)
    userlist                     = base64encode(local.userlist)
    project_id                   = var.project_id
    cloud_sql_proxy_image        = var.cloud_sql_proxy_image
    cloud_sql_instance_name      = module.db.instance_connection_name
    cloud_sql_replica_name       = module.db.replicas_instance_connection_names[0]
    cloud_sql_proxy_port         = var.cloud_sql_proxy_port
    configure_hammerdb           = base64encode(local.configure_hammerdb)
    configure_hammerdb_tcl       = base64encode(local.configure_hammerdb_tcl)
    run_workload                 = base64encode(local.run_workload)
    run_workload_tcl             = base64encode(local.run_workload_tcl)
    start_all_services           = base64encode(local.start_all_services)
    stop_all_services            = base64encode(local.stop_all_services)
    terminate_active_connections = base64encode(local.terminate_active_connections)
    clean_up                     = base64encode(local.clean_up)
  }
  depends_on = [
    module.db,
  ]
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


module "activate-services" {
  source = "terraform-google-modules/project-factory/google//modules/project_services"

  project_id  = var.project_id
  enable_apis = true

  disable_services_on_destroy = true

  activate_apis = [
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
  ]

  activate_api_identities = [{
    api = "servicenetworking.googleapis.com"
    roles = [
      "roles/servicenetworking.serviceAgent",
    ]
  }]

}


module "vpc_network" {
  source           = "terraform-google-modules/network/google"
  version          = "5.1.0"
  project_id       = var.project_id
  network_name     = var.network_name
  subnets          = var.subnets
  secondary_ranges = var.secondary_ranges
  depends_on = [
    module.activate-services
  ]
}

data "google_compute_image" "boot" {
  project = split("/", var.boot_image)[0]
  family  = split("/", var.boot_image)[1]
  depends_on = [
    module.activate-services
  ]
}

# Compute instance to run pgbouncer and cloud_sql_proxy
resource "google_compute_instance" "pgbouncer_instance" {
  name         = "pgbouncer-instance-${random_id.suffix.hex}"
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
    network            = module.vpc_network.network_name
    subnetwork_project = module.vpc_network.project_id
    subnetwork         = module.vpc_network.subnets[keys(module.vpc_network.subnets)[0]].name
    access_config {

    }
  }

  tags = ["pgbouncer"]

  depends_on = [
    module.db
  ]

}

# Firewall rule to allow ssh access to the pgbouncer instance
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

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["pgbouncer"]


}



# Creating a service account for the Cloud SQL Proxy 
module "cloud_sql_proxy_service_account" {
  source  = "terraform-google-modules/service-accounts/google"
  version = "3.0.0"

  project_id = var.project_id
  names      = ["cloud-sql-proxy"]
  project_roles = [
    "${var.project_id}=>roles/cloudsql.admin",
    "${var.project_id}=>roles/storage.admin",
  ]
}

# Private service access for Cloud SQL
module "private_service_access" {
  source  = "GoogleCloudPlatform/sql-db/google//modules/private_service_access"
  version = "~>5.0.0"

  project_id  = var.project_id
  vpc_network = module.vpc_network.network_name

  depends_on = [
    module.vpc_network,
  ]
}


# Postgres HA Cloud SQL instance
module "db" {
  source  = "GoogleCloudPlatform/sql-db/google//modules/postgresql"
  version = "~>5.0.0"

  project_id           = var.project_id
  name                 = "db-pgbouncer"
  random_instance_name = true

  database_version = "POSTGRES_14"
  region           = var.region
  zone             = var.zone
  tier             = "db-f1-micro"

  db_name       = var.db_name
  user_name     = var.db_user
  user_password = var.db_password

  # additional_users = var.users

  availability_type = "REGIONAL"

  deletion_protection = false

  ip_configuration = {
    ipv4_enabled    = false
    private_network = module.vpc_network.network_self_link
    require_ssl     = false
    authorized_networks = [
      {
        name  = "${var.project_id}-cidr"
        value = module.vpc_network.subnets[keys(module.vpc_network.subnets)[0]].ip_cidr_range
      }
    ]
  }

  # Read replica configurations
  read_replica_name_suffix = "-ha"
  read_replicas = [
    {
      name                  = "-0"
      zone                  = "us-east1-b"
      availability_type     = "REGIONAL"
      tier                  = "db-f1-micro"
      ip_configuration      = local.read_replica_ip_configuration
      database_flags        = [{ name = "autovacuum", value = "off" }]
      disk_autoresize       = null
      disk_autoresize_limit = null
      disk_size             = null
      disk_type             = "PD_HDD"
      encryption_key_name   = null
      user_labels           = null
      deletion_protection   = false
    }
  ]


  module_depends_on = [module.private_service_access.peering_completed]

  create_timeout = "2h"
  delete_timeout = "2h"
  update_timeout = "2h"

}

output "db_connection_name" {
  value = module.db.instance_connection_name
}

output "read_replica_connection_name" {
  value = module.db.replicas_instance_connection_names
}
output "PgBouncer" {
  value = google_compute_instance.pgbouncer_instance.name
}


