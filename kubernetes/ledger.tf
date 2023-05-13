# This will work for hosts managed by this operator
# endpoints can be added for external hosts
resource "kubernetes_manifest" "service_election_votingapp" {
  manifest = {
    "apiVersion" = "v1"
    "kind" = "Service"
    "metadata" = {
      "name" = "votingapp"
      "namespace" = "election"
    }
    "spec" = {
      "clusterIP" = "None"
      "ports" = [
        {
          "name" = "validator"
          "port" = 8800
        },
      ]
      "selector" = {
        "app.kubernetes.io/name" = "ledger"
      }
    }
  }
}

resource "kubernetes_manifest" "statefulset_election_ledger_node" {
  manifest = {
    "apiVersion" = "apps/v1"
    "kind" = "StatefulSet"
    "metadata" = {
      "name" = "ledger"
      "namespace" = "election"
    }
    "spec" = {
      "replicas" = length(var.ledger_hosts)
      "selector" = {
        "matchLabels" = {
          "app.kubernetes.io/name" = "ledger"
        }
      }
      "serviceName" = "votingapp"
      "template" = {
        "metadata" = {
          "labels" = {
            "app" = "ledger"
            "app.kubernetes.io/name" = "ledger"
          }
        }
        "spec" = {
          "affinity" = {
            "podAntiAffinity" = {
              "preferredDuringSchedulingIgnoredDuringExecution" = [
                {
                  "podAffinityTerm" = {
                    "labelSelector" = {
                      "matchExpressions" = [
                        {
                          "key" = "app.kubernetes.io/name"
                          "operator" = "In"
                          "values" = [
                            "ledger",
                          ]
                        },
                      ]
                    }
                    "topologyKey" = "kubernetes.io/hostname"
                  }
                  "weight" = 100
                },
              ]
            }
          }
          "containers" = [
            {
              "command" = [
                "bash",
                "-c",
                "settings-tp -v -C tcp://$HOSTNAME:4004",
              ]
              "image" = "hyperledger/sawtooth-settings-tp:chime"
              "imagePullPolicy" = "Always"
              "name" = "settings-tp"
            },
            {
              "command" = [
                "bash",
                "-c",
                "identity-tp -v -C tcp://$HOSTNAME:4004",
              ]
              "image" = "hyperledger/sawtooth-identity-tp:chime"
              "name" = "identity-tp"
            },
            {
              "command" = [
                "/bin/bash",
                "/init/init-validator.sh",
              ]
              "env" = [
                {
                  "name" = "GENESIS_PATH"
                  "value" = "/mnt"
                },
              ]
              "image" = "hyperledger/sawtooth-validator:chime"
              "name" = "validator"
              "ports" = [
                {
                  "name": "tp",
                  "containerPort" = 4004
                },
                {
                  "name": "validator"
                  "containerPort" = 8800
                },
                {
                  "name": "consensus"
                  "containerPort" = 5050
                },
              ]
              "volumeMounts" = [
                {
                  "mountPath" = "/etc/sawtooth/keys"
                  "name" = "validator-key"
                  "readOnly" = true
                },
                {
                  "mountPath" = "/mnt/genesis"
                  "name" = "genesis-batch"
                  "readOnly" = true
                },
                {
                  "mountPath" = "/mnt/config"
                  "name" = "validator-toml"
                  "readOnly" = true
                },
                {

                  "mountPath" = "/init"
                  "name" = "validator-init"
                },
                {
                  "mountPath" = "/var/lib/sawtooth"
                  "name" = "ledger-data"
                },
              ]
            },
            {
              "command" = [
                "bash",
                "-c",
                "pbft-engine -v -C tcp://$HOSTNAME:5050",
              ]
              "image" = "hyperledger/sawtooth-pbft-engine:chime"
              "name" = "pbft-engine"
            },
            {
              "command" = [
                "bash",
                "-c",
                "sawtooth-rest-api -v -C tcp://$HOSTNAME:4004 --bind 0.0.0.0:8008",
              ]
              "image" = "hyperledger/sawtooth-rest-api:chime"
              "name" = "rest-api"
              "ports" = [
                {
                  "containerPort" = 8008
                },
              ]
              "volumeMounts" = [
                {
                  "mountPath" = "/etc/sawtooth/"
                  "name" = "sawtooth-rest-api-toml"
                  "readOnly" = true
                }
              ]
            },
            {
              "command" = [
                "/bin/sh",
                "-c",
                "VALIDATOR_HOST=$HOSTNAME /usr/local/bin/node /home/node/votingapp-ledger/dist/election-management-tp/index.js",
              ]
              "env" = [
                {
                  "name" = "ROOT_CERT"
                  "valueFrom" = {
                    "secretKeyRef" = {
                      "key" = "system-root"
                      "name" = "certificates"
                      "optional" = false
                    }
                  }
                },
                {
                  "name" = "SECDEV_CA_CERT"
                  "valueFrom" = {
                    "secretKeyRef" = {
                      "key" = "secdev-ca"
                      "name" = "certificates"
                      "optional" = false
                    }
                  }
                },
                {
                  "name" = "SECDEV_DIGITAL_SIGNATURE_CERT"
                  "valueFrom" = {
                    "secretKeyRef" = {
                      "key" = "secdev-digital-signature"
                      "name" = "certificates"
                      "optional" = false
                    }
                  }
                },
              ]
              "image" = "registry.gitlab.com/vidaloop/votingapp/package-registry/transaction-processor:${var.release_version}"
              "name" = "election-management-tp"
              "imagePullPolicy" = "Always"
            },
            {
              "command" = [
                "/bin/sh",
                "-c",
                "VALIDATOR_HOST=$HOSTNAME /usr/local/bin/node /home/node/votingapp-ledger/dist/election-casting-tp/index.js",
              ]
              "image" = "registry.gitlab.com/vidaloop/votingapp/package-registry/transaction-processor:${var.release_version}"
              "name" = "election-casting-tp"
              "imagePullPolicy" = "Always"
            },
            {
              "command" = [
                "/rest-api"
              ]
              "image" = "registry.gitlab.com/vidaloop/votingapp/package-registry/votingapp-rest-api:${var.release_version}"
              "name" = "votingapp-rest-api"
              "imagePullPolicy" = "Always"
              "ports" = [
                {
                  "containerPort" = 3030
                },
              ],
              "env" = [
                {
                  "name" = "HOST"
                  "value" = "${var.endpoint}"
                },
                {
                  "name" = "PORT"
                  "value" = "3030"
                },
                {
                  "name" = "RUST_LOG"
                  "value" = "info"
                },
                {
                  "name" = "SAWTOOTH_REST_API"
                  "value" = "http://localhost:8008"
                },
                {
                  "name" = "AUTHENTICATE"
                  "value" = "${var.http_authenticate}"
                },
                {
                  "name" = "HTTP_SIGNING_KEY"
                  "value" = "${var.http_certificate_name}.priv.pem"
                },
                {
                  "name" = "HTTP_SIGNING_KEY_PUB"
                  "value" = "${var.http_certificate_name}.crt.pem"
                },
                {
                  "name" = "VA_CERTIFICATE_CHAIN"
                  "value" = "${var.http_certificate_name}.chain.pem"
                },
              ],
              "volumeMounts" = [
                {
                  "mountPath" = "/assets"
                  "name" = "http-assets"
                  "readOnly" = true
                },
                {
                  "mountPath" = "/tls"
                  "name" = "tls-config"
                  "readOnly" = true
                }
              ]
            }
          ]
          "imagePullSecrets" = [
            {
              "name" = "docker-registry"
            },
          ]
          "initContainers" = [
            {
              "command" = [
                "/bin/sh",
                "/init/copy-keys.sh",
              ]
              "image" = "alpine:latest"
              "name" = "key-distribution"
              "volumeMounts" = [
                {
                  "mountPath" = "/mnt/node"
                  "name" = "validator-key"
                },
                {
                  "mountPath" = "/mnt/http"
                  "name" = "http-assets"
                },
                {
                  "mountPath" = "/mnt/allkeys"
                  "name" = "validator-keys"
                },
                {
                  "mountPath" = "/init"
                  "name" = "validator-init"
                },
              ]
            },
          ]
          "volumes" = [
            {
              "emptyDir" = {}
              "name" = "validator-key"
            },
            {
              "emptyDir" = {}
              "name" = "http-assets"
            },
            {
              "name" = "validator-keys"
              "secret" = {
                "defaultMode" = 256
                "secretName" = "validator-keys"
              }
            },
            {
              "name" = "ems-keys"
              "secret" = {
                "defaultMode" = 256
                "secretName" = "ems-keys"
              }
            },
            {
              "name" = "validator-toml"
              "secret" = {
                "defaultMode" = 256
                "secretName" = "validator-toml"
              }
            },
            {
              "configMap" = {
                "name" = "sawtooth-rest-api-toml"
              }
              "name" = "sawtooth-rest-api-toml"
            },
            {
              "configMap" = {
                "name" = "genesis-batch"
              }
              "name" = "genesis-batch"
            },
            {
              "configMap" = {
                "name" = "validator-init"
              }
              "name" = "validator-init"
            },
            {
              "name" = "tls-config"
              "secret" = {
                "defaultMode" = 256
                "secretName" = "tls-config"
              }
            },
            {
              "name" = "rest-api-assets"
              "secret" = {
                "defaultMode" = 256
                "secretName" = "rest-api-assets"
              }
            }
          ]
        }
      }
      "volumeClaimTemplates" = [
        {
          "metadata" = {
            "name" = "ledger-data"
            "namespace" = "election"
          }
          "spec" = {
            "accessModes" = [
              "ReadWriteOnce",
            ]
            "resources" = {
              "requests" = {
                "storage" = "10Gi"
              }
            }
            "storageClassName" = "gp2"
          }
        },
      ]
    }
  }
}
