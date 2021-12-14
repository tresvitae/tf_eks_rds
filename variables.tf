variable "region" {
    type = string
    default = "eu-west-1"
}

variable "vpc_cidr_block" {
  type = string
  default = "10.0.0.0/16"
}
variable "environment" {
  type = string
  default = "dev"
}