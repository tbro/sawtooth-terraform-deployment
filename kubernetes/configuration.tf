resource "kubernetes_secret" "validator_toml" {
  metadata {
    name = "validator-toml"
    namespace = "election"
  }

  binary_data = {
    "validator.toml" = "${filebase64("${path.module}/provision/validator.toml")}"
  }
}

// FIXME re-enable management-tp Authentication
// resource "kubernetes_config_map" "management_policy" {
//   metadata {
//     name = "management-policy"
//     namespace = "election"
//   }
//
//   data = {
//     "policy.election_managers" = local.policy
//   }
// }

resource "kubernetes_config_map" "sawtooth_rest_api_toml" {
  metadata {
    name = "sawtooth-rest-api-toml"
    namespace = "election"
  }

  binary_data = {
    "rest_api.toml" = "${filebase64("${path.module}/rest_api.toml")}"
  }
}

resource "kubernetes_config_map" "genesis_batch" {
  metadata {
    name = "genesis-batch"
    namespace = "election"
  }

  binary_data = {
    "genesis.batch" = "${filebase64("${path.module}/provision/genesis.batch")}"
  }
}

locals {
  init-validator = templatefile("${path.module}/init-validator.tftmpl", {nodes = var.ledger_hosts})
}

resource "kubernetes_config_map" "validator-init" {
  metadata {
    name = "validator-init"
    namespace = "election"
  }

  binary_data = {
    "init-validator.sh" = "${base64encode("${local.init-validator}")}"
    "copy-keys.sh" = "${filebase64("${path.module}/copy-keys.sh")}"
  }
}



resource "kubernetes_secret" "docker-registry" {
  metadata {
    name = "docker-registry"
    namespace = "election"
  }

  data = {
    ".dockerconfigjson" = "${file("${var.docker-config-file}")}"
  }

  type = "kubernetes.io/dockerconfigjson"

}


resource "kubernetes_secret" "certificates" {
  metadata {
    name = "certificates"
    namespace = "election"
  }
  data = {
    secdev-ca = trimspace("${file("${path.module}/provision/${var.ca_cert_file}")}")
    system-root = trimspace("${file("${path.module}/provision/${var.root_cert_file}")}")
    secdev-digital-signature = trimspace("${file("${path.module}/provision/${var.secdev_sig_cert_file}")}")
  }

  type = "Opaque"
}

resource "kubernetes_secret" "tls-config" {
  metadata {
    name = "tls-config"
    namespace = "election"
  }
  data = {
    "key.rsa" = trimspace("${file("${path.module}/tls/${var.tls_key_file}")}")
    "cert.pem" = trimspace("${file("${path.module}/tls/${var.tls_cert_file}")}")
  }

  type = "Opaque"
}

// FIXME change names to match provisioning package
resource "kubernetes_secret" "validator_keys" {
  metadata {
    name = "validator-keys"
    namespace = "election"
  }
  data = merge(
    {
      for host in var.ledger_hosts: "validator_${index(var.ledger_hosts, host)}.priv" =>
      file("${path.module}/provision/${host}/${var.validator_key_name}.priv")
    },
    {
      for host in var.ledger_hosts: "validator_${index(var.ledger_hosts, host)}.pub" =>
      file("${path.module}/provision/${host}/${var.validator_key_name}.pub")
    },
    {
      for host in var.ledger_hosts: "${var.http_certificate_name}_${index(var.ledger_hosts, host)}.priv.pem" =>
      file("${path.module}/provision/${host}/${var.http_certificate_name}.priv.pem")
    },
    {
      for host in var.ledger_hosts: "${var.http_certificate_name}_${index(var.ledger_hosts, host)}.crt.pem" =>
      file("${path.module}/provision/${host}/${var.http_certificate_name}.crt.pem")
    },
    {
      for host in var.ledger_hosts: "${var.http_certificate_name}_${index(var.ledger_hosts, host)}.chain.pem" =>
      file("${path.module}/provision/${host}/${var.http_certificate_name}.chain.pem")
    }
    )

  type = "Opaque"
}

# output "validator_init" {
#   value = local.init-validator
# }
