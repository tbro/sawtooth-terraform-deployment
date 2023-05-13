variable "ledger_hosts" {
  description = "Array with host name of each node"
  type        = list(string)
}
variable "validator_key_name" {
  description = "Basename of files holding validator pub/priv keys"
  type        = string
  default     = "ledger-node-auth-digital-signature"
}
variable "http_key_name" {
  description = "Basename of files holding http keys and certs"
  type        = string
  default     = "ledger-node-http-digital-signature"
}
variable "ca_cert_file" {
  description = "Ca certificate PEM file name"
  type        = string
  default     = "secdev-ca.crt.pem"
}
variable "root_cert_file" {
  description = "Root certificate PEM file name"
  type        = string
  default     = "system-root.crt.pem"
}
variable "secdev_sig_cert_file" {
  description = "Security-device signature certificate PEM file name"
  type        = string
  default     = "secdev-digital-signature.crt.pem"
}
variable "aws_route53_zone_id" {
  description = "Route 53 zone ID"
  type = string
}
variable "http_authenticate" {
  description = "Set to true to force rest API to authenticate clients"
  type = bool
  default = "false"
}
variable "http_certificate_name" {
  description = "Base name of files holding http signing key and chain"
  type = string
  default = "ledger-node-http-digital-signature"
}
variable "tls_cert_file" {
  description = "File holding TLS certificate"
  type = string
  default = "cert.pem"
}
variable "tls_key_file" {
  description = "File holding TLS signing key"
  type = string
  default = "key.rsa"
}
variable "release_version" {
  description = "A docker tag we should target"
  type = string
}
variable "endpoint" {
  description = "Load balancing endpoint."
  type = string
}
variable "docker-config-file" {
  description = "Path to dockerconfigjson."
  type = string
}
