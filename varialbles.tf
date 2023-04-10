variable "project_id" {
  type        = string
  default     = "sapient-helix-352609"
  description = "value of project id"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "value of region"
}

variable "network_name" {
  type        = string
  default     = "pgbouncer-network"
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

variable "instance_name" {
  type        = string
  default     = "instance-1"
  description = "value of instance name"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "value of environment"
}

variable "db_name" {
  type        = string
  default     = "test"
  description = "value of db name"
}

variable "db_user" {
  type        = string
  default     = "admin"
  description = "value of db username"
}

variable "db_password" {
  type        = string
  default     = "admin@123"
  description = "value of db password"
}

# Define variables
variable "db_instance_connection_name" {
  type        = string
  description = "The connection name of the Cloud SQL instance"
  default     = "sapient-helix-352609:us-central1:pg-ha-6c8f5ad3"
}




variable "database_host" {
  description = "The host address of the Cloud SQL instance to connect to."
  type        = string
  default     = "sapient-helix-352609:us-central1:pg-ha-6c8f5ad3"
}

variable "database_port" {
  description = "The port to connect to the database with."
  type        = number
  default     = 5432
}

variable "listen_port" {
  description = "The port used by PgBouncer to listen on."
  type        = number
  default     = 6432
}

variable "users" {
  description = "The list of users to be created in PgBouncer's userlist.txt. Passwords can be provided as plain-text or md5 hashes."
  type        = list(any)
  default = [
    {
      name     = "admin"
      password = "admin@123"
    },
    {
      name : "test"
      password : "test123"
    },
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
  description = "The maximum number of server connections per database (regardless of user). 0 is unlimited."
  type        = number
  default     = 0
}

variable "max_client_conn" {
  description = "The maximum number of server connections per database (regardless of user). 0 is unlimited."
  type        = number
  default     = 0
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
