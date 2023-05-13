module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 18.0"
  cluster_name    = local.cluster_name
  cluster_version = local.cluster_version
  subnet_ids        = module.vpc.private_subnets

  vpc_id = module.vpc.vpc_id

  # Self managed node groups will not automatically create the aws-auth configmap so we need to
  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  self_managed_node_group_defaults = {
    create_security_group = false
  }

  self_managed_node_groups = {
    # Bottlerocket node group
    bottlerocket = {
      name = "bottlerocket-self-mng"

      platform      = "bottlerocket"
      ami_id        = data.aws_ami.eks_default_bottlerocket.id
      instance_type = "t2.small"
      min_size      = length(var.ledger_hosts)
      max_size      = length(var.ledger_hosts)
      desired_size  = length(var.ledger_hosts)
      key_name      = aws_key_pair.this.key_name

      iam_role_additional_policies = [
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      ]


      bootstrap_extra_args = <<-EOT
      # The admin host container provides SSH access and runs with "superpowers".
      # It is disabled by default, but can be disabled explicitly.
      [settings.host-containers.admin]
      enabled = false
      # The control host container provides out-of-band access via SSM.
      # It is enabled by default, and can be disabled if you do not expect to use SSM.
      # This could leave you with no way to access the API and change settings on an existing node!
      [settings.host-containers.control]
      enabled = true
      [settings.kubernetes.node-labels]
      ingress = "allowed"
      EOT
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

data "aws_ami" "eks_default_bottlerocket" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["bottlerocket-aws-k8s-${local.cluster_version}-x86_64-*"]
  }
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
}

resource "aws_key_pair" "this" {
  key_name   = local.cluster_name
  public_key = tls_private_key.this.public_key_openssh
}

locals {
  cluster_version = "1.22"
}

# resource "aws_eks_addon" "addons" {
#   cluster_name      = module.eks.cluster_id
#   addon_name        = "aws-ebs-csi-driver"
#   addon_version     = "v1.10.0-eksbuild.1"
#   resolve_conflicts = "OVERWRITE"
# }

# aws eks --region us-east-1 update-kubeconfig --name $(terraform output -raw cluster_id)

resource "kubernetes_namespace" "election" {
  metadata {
    name = "election"
  }
}

# these should probably be ingresses
resource "kubernetes_service" "www" {
  count = length(var.ledger_hosts)
  metadata {
    name = "www-${count.index}"
    namespace = "election"
  }
  spec {
    port {
      name        = "votingapp-rest-api"
      port        = 443
      target_port = 3030
    }
    external_traffic_policy = "Local"
    type = "LoadBalancer"
    selector = {
      "app.kubernetes.io/name" = "ledger"
    }
  }
}

resource "kubernetes_service" "endpoint" {
  metadata {
    name = "ledger-endpoint"
    namespace = "election"
  }
  spec {
    port {
      name        = "votingapp-rest-api"
      port        = 443
      target_port = 3030
    }
    type = "LoadBalancer"
    selector = {
      "app.kubernetes.io/name" = "ledger"
    }
  }
}

locals {
  lb_hosts = kubernetes_service.www[*].status.0.load_balancer.0.ingress.0.hostname
  endpoint_host = kubernetes_service.endpoint.status.0.load_balancer.0.ingress.0.hostname
}

# can be used to connect to external validators
# resource "kubernetes_service" "validator" {
#   count = length(var.ledger_hosts)
#   metadata {
#     name = "validator-${count.index}"
#     namespace = "election"
#   }
#   spec {
#     type = "ExternalName"
#     external_name = "${local.lb_hosts[count.index]}"
#   }
# }

resource "aws_route53_record" "www" {
  count = length(var.ledger_hosts)
  zone_id = var.aws_route53_zone_id
  name = "${var.ledger_hosts[count.index]}"
  type    = "CNAME"
  ttl     = "300"
  records = [local.lb_hosts[count.index]]
}

resource "aws_route53_record" "endpoint" {
  zone_id = var.aws_route53_zone_id
  name = "${var.endpoint}"
  type    = "CNAME"
  ttl     = "300"
  records = [local.endpoint_host]
}

output "lb_hosts" {
  value = local.lb_hosts
}
output "www_dns_records" {
  value = aws_route53_record.www[*]
}
