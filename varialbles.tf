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



