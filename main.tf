provider "google" {
  project = var.project_id
  region  = var.region
  # zone    = var.zone
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
  startup_script = templatefile("${path.module}/templates/startup-script.sh.tmpl", {
    cloud_sql_proxy_download_url = var.cloud_sql_proxy_download_url
    database_connection_name     = var.database_connection_name
  })
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
    # Install PgBouncer and Cloud SQL Proxy
    "pgbouncer-version"       = "1.15.0"
    "cloud-sql-proxy-version" = "1.28.0"
    user-data                 = data.cloudinit_config.cloud_config.rendered
    startup-script            = local.startup_script
  }

  boot_disk {
    initialize_params {
      image = data.google_compute_image.boot.self_link
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
    ports    = ["3307"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["pgbouncer"]
}





