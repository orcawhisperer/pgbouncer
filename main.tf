// terraform code to deploy postgresql cloud sql instance with HA enabled 

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

// Create a VPC network and subnet and Cloud SQL HA instance 

module "network" {
  source = "terraform-google-modules/network/google"

  project_id   = var.project_id
  network_name = "pgbouncer-network"
  routing_mode = "GLOBAL"
  subnets = [
    {
      subnet_name   = "subnet-1"
      subnet_ip     = "10.10.10.0/24"
      subnet_region = "us-west1"

    },
    {
      subnet_name   = "subnet-2"
      subnet_ip     = "10.10.20.0/24"
      subnet_region = "us-west2"
    },
    {
      subnet_name   = "subnet-3"
      subnet_ip     = "10.10.30.0/24"
      subnet_region = "us-west3"
    }
  ]

}

locals {
  read_replica_ip_configuration = {
    ipv4_enabled       = true
    require_ssl        = false
    private_network    = null
    allocated_ip_range = null
    authorized_networks = [
      {
        name  = "${var.project_id}-cidr"
        value = var.pg_ha_external_ip_range
      },
    ]
  }
}

module "pg" {
  source               = "GoogleCloudPlatform/sql-db/google//modules/postgresql"
  version              = "8.0.0"
  name                 = var.pg_ha_name
  random_instance_name = true
  project_id           = var.project_id
  database_version     = "POSTGRES_12"
  region               = "us-central1"

  // Master configurations
  tier                            = "db-custom-1-3840"
  zone                            = "us-central1-c"
  availability_type               = "REGIONAL"
  maintenance_window_day          = 7
  maintenance_window_hour         = 12
  maintenance_window_update_track = "stable"

  deletion_protection = false

  database_flags = [{ name = "autovacuum", value = "off" }]

  user_labels = {
    foo = "bar"
  }

  ip_configuration = {
    ipv4_enabled       = true
    require_ssl        = true
    private_network    = null
    allocated_ip_range = null
    authorized_networks = [
      {
        name  = "${var.project_id}-cidr"
        value = var.pg_ha_external_ip_range
      },
    ]
  }

  backup_configuration = {
    enabled                        = true
    start_time                     = "20:55"
    location                       = null
    point_in_time_recovery_enabled = false
    transaction_log_retention_days = null
    retained_backups               = 365
    retention_unit                 = "COUNT"
  }

  // Read replica configurations
  read_replica_name_suffix = "-test"
  read_replicas = [
    {
      name                  = "0"
      zone                  = "us-central1-a"
      availability_type     = "REGIONAL"
      tier                  = "db-custom-1-3840"
      ip_configuration      = local.read_replica_ip_configuration
      database_flags        = [{ name = "autovacuum", value = "off" }]
      disk_autoresize       = null
      disk_autoresize_limit = null
      disk_size             = null
      disk_type             = "PD_HDD"
      user_labels           = { bar = "baz" }
      encryption_key_name   = null
    },
    {
      name                  = "1"
      zone                  = "us-central1-b"
      availability_type     = "REGIONAL"
      tier                  = "db-custom-1-3840"
      ip_configuration      = local.read_replica_ip_configuration
      database_flags        = [{ name = "autovacuum", value = "off" }]
      disk_autoresize       = null
      disk_autoresize_limit = null
      disk_size             = null
      disk_type             = "PD_HDD"
      user_labels           = { bar = "baz" }
      encryption_key_name   = null
    },
    {
      name                  = "2"
      zone                  = "us-central1-c"
      availability_type     = "REGIONAL"
      tier                  = "db-custom-1-3840"
      ip_configuration      = local.read_replica_ip_configuration
      database_flags        = [{ name = "autovacuum", value = "off" }]
      disk_autoresize       = null
      disk_autoresize_limit = null
      disk_size             = null
      disk_type             = "PD_HDD"
      user_labels           = { bar = "baz" }
      encryption_key_name   = null
    },
  ]

  db_name      = var.pg_ha_name
  db_charset   = "UTF8"
  db_collation = "en_US.UTF8"

  additional_databases = [
    {
      name      = "${var.pg_ha_name}-additional"
      charset   = "UTF8"
      collation = "en_US.UTF8"
    },
  ]

  user_name     = "tftest"
  user_password = "foobar"

  additional_users = [
    {
      name            = "tftest2"
      password        = "abcdefg"
      host            = "localhost"
      random_password = false
    },
    {
      name            = "tftest3"
      password        = "abcdefg"
      host            = "localhost"
      random_password = false
    },
  ]
}

module "service_account" {
  source     = "terraform-google-modules/service-accounts/google"
  project_id = var.project_id
  names      = ["pgbouncer"]
  project_roles = [
    "${var.project_id}=>roles/cloudsql.client",
    "${var.project_id}=>roles/compute.networkViewer",
    "${var.project_id}=>roles/compute.securityAdmin",
    "${var.project_id}=>roles/iam.serviceAccountUser",
  ]
}



// PgBouncer instance template with startup script
module "pg_bouncer_instance_template" {
  source       = "terraform-google-modules/vm/google//modules/instance_template"
  region       = "us-central1"
  project_id   = var.project_id
  name_prefix  = "pgbouncer"
  machine_type = "n1-standard-1"

  network    = module.network.network_name
  subnetwork = module.network.subnets[0].subnet_name

  startup_script = file("pgbouncer_startup_script.sh")

  service_account = {
    email  = module.service_account.email
    scopes = ["cloud-platform"]
  }

  tags = ["pgbouncer"]
}

// PgBouncer instance
module "pg_bouncer_instance" {
  source            = "terraform-google-modules/vm/google//modules/compute_instance"
  instance_template = module.pg_bouncer_instance_template.self_link
  subnetwork        = module.network.subnets[0].subnet_name
  region            = "us-central1"
  zone              = "us-central1-a"
}

resource "google_compute_firewall" "pgbouncer" {
  name    = "pgbouncer-firewall"
  network = module.network.network_name
  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = module.pg_bouncer_instance_template.tags
}





