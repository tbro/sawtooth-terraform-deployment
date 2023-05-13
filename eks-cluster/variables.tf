variable "aws_config_dir" {
  description = "Directory with aws configuration and credentials (/home/user/.aws)"
  type = string
  default = "$HOME/.aws"
}
variable "aws_config_provile" {
  description = "Directory with aws configuration and credentials (/home/user/.aws)"
  type = string
  default = "es-dev-personal"
}
variable "ledger_hosts" {
  description = "Array with host name of each node"
  type        = list(string)
}
variable "aws_profile" {
  description = "AWS profile to use for deployment"
  type        = string
}
variable "aws_route53_zone_id" {
  description = "Route 53 zone ID"
  type = string
}
variable "endpoint" {
  description = "Load balancing endpoint."
  type = string
}
