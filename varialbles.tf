variable "project_id" {
  type        = string
  default     = "mineral-anchor-361313"
  description = "value of project id"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "value of region"
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
  default     = "root"
  description = "value of db username"
}

variable "db_password" {
  type        = string
  default     = "Root@123"
  description = "value of db password"
}


