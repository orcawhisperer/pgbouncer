variable "project_id" {
  type        = string
  description = "value of project id"
}

variable "region" {
  type        = string
  description = "value of region"
}

variable "zone" {
  type        = string
  description = "value of zone"
}

variable "network_name" {
  type        = string
  description = "value of network name"
}

variable "subnets" {
  type = list(object({
    subnet_name           = string
    subnet_ip             = string
    subnet_region         = string
    subnet_private_access = bool
  }))
  default = [
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
}

variable "secondary_ranges" {
  type = map(list(object({
    range_name    = string
    ip_cidr_range = string
  })))
  default = {
    us-central1-subnet = [
      {
        range_name    = "us-central1-subnet"
        ip_cidr_range = "10.100.1.128/25"
      }
    ],
    us-east1-subnet = [
      {
        range_name    = "us-east1-subnet"
        ip_cidr_range = "10.100.2.128/25"
      }
    ],
    us-west1-subnet = [
      {
        range_name    = "us-west1-subnet"
        ip_cidr_range = "10.100.3.128/25"
      }
    ]
  }
}

variable "db_name" {
  type        = string
  default     = "test"
  description = "value of db name"
}

variable "db_user" {
  type        = string
  description = "value of db username"
}

variable "db_password" {
  type        = string
  description = "value of db password"
}

variable "listen_port" {
  description = "The port used by PgBouncer to listen on."
  type        = number
  default     = 6432
}

variable "users" {
  description = "The list of users to be created in PgBouncer's userlist.txt. Passwords can be provided as plain-text."
  type        = list(any)
  default = [
    {
      name : "admin"
      password : "admin@123"
    },
    {
      name : "postgres"
      password : "admin@123"
    }
  ]
}

variable "auth_user" {
  description = "Any user not specified in `users` will be queried through the `auth_query` query from `pg_shadow` in the database, using `auth_user`. The user for `auth_user` must be included in `users`."
  type        = string
  default     = null
}

variable "auth_query" {
  description = "Query to load user’s password from database."
  type        = string
  default     = null
}

variable "pool_mode" {
  description = "Specifies when a server connection can be reused by other clients. Possible values are `session`, `transaction` or `statement`."
  type        = string
  default     = "transaction"
}

variable "default_pool_size" {
  description = "Maximum number of server connections to allow per user/database pair."
  type        = number
  default     = 20
}

variable "max_client_connections" {
  description = "Maximum number of client connections allowed."
  type        = number
  default     = 100
}

variable "max_db_connections" {
  description = "The maximum number of server connections per database (regardless of user)."
  type        = number
  default     = 100
}

variable "max_client_conn" {
  description = "The maximum number of server connections per database (regardless of user)."
  type        = number
  default     = 100
}

variable "custom_config" {
  description = "Custom PgBouncer configuration values to be appended to `pgbouncer.ini`."
  type        = string
  default     = ""
}

variable "pgbouncer_image_tag" {
  description = "The tag to use for the base PgBouncer `edoburu/pgbouncer` Docker image used by this module."
  default     = "latest"
}

variable "boot_image" {
  description = "The boot image used by PgBouncer instances. Defaults to the latest LTS Container Optimized OS version. Must be an image compatible with cloud-init (https://cloud-init.io)."
  type        = string
  default     = "cos-cloud/cos-101-lts"
}

variable "cloud_sql_proxy_port" {
  default     = 5432
  type        = number
  description = "The port to use for the cloud_sql_proxy to listen on."
}

variable "cloud_sql_proxy_image" {
  default     = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.1.2"
  type        = string
  description = "The image to use for the cloud_sql_proxy container."
}

variable "cloud_sql_proxy_host" {
  default     = "cloudsql-proxy"
  type        = string
  description = "The host to use for the cloud_sql_proxy to listen on."
}

variable "pgbouncer_host" {
  default     = "pgbouncer"
  type        = string
  description = "Hostname of pgbouncer service"
}

variable "hammerdb_user" {
  default     = "hammerdb"
  type        = string
  description = "Username for hammerdb"
}

variable "hammerdb_pass" {
  default     = "hammerdb"
  type        = string
  description = "Password for hammerdb"
}

variable "cloud_sdk_image" {
  default     = "gcr.io/google.com/cloudsdktool/cloud-sdk:alpine"
  type        = string
  description = "value of cloud sdk image"
}





