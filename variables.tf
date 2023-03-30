# instance_name = {
#   type        = string
#   description = "Name of the instance"
# }

# machine_type = {
#   type        = string
#   description = "Machine type of the instance"
# }

# image = {
#   type        = string
#   description = "Image of the instance"
# }

# network = {
#   type        = string
#   description = "Network of the instance"
# }




variable "pg_ha_name" {
  type        = string
  description = "Name of the cloud sql instance"
  default     = "pg-ha"
}

variable "pg_ha_external_ip_range" {
  type        = string
  description = "External IP range of the cloud sql instance"
  default     = "10.10.10.0/24"
}

variable "project_id" {
  type        = string
  description = "Project ID"
  default     = "sapient-helix-352609"
}

variable "region" {
  type        = string
  description = "value of the region"
  default     = "us-central1"

}

variable "zone" {
  type        = string
  description = "value of the zone"
  default     = "us-central1-a"
}

