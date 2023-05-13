# Reproducible Deployments

> Published with kind permission from [vidaloop](https://www.vidaloop.com/vidaloop-innovator-in-mobile-voting-shutdown-of-operations).

## prerequisites

You will need [AWS CLI 2](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html), [terraform](https://www.terraform.io/downloads).

First, assure that you are in the `deploy` sub-directory of this repo. You will need a folder produced by the [ledger-provision](utility) in the `kubernetes` subdirectory. If you have the prerequisites setup correctly the following will output some variable definitions:

    cat kubernetes/provision/terraform.tfvars

In addition you will need an AWS route 53 zone ID to register the ledger hosts with the endpoints configured in the provisioning package. Terraform will ask you for this ID when you deploy your infrastructure.

## terraform

Terraform configuration has been split into two modules. The first creates AWS VPC, EKS Cluster, EC2 instances and related networking resources. The second creates our `election` namespace in the kubernetes cluster, deploys configuration and secrets, and initializes load-balancer services for each node.

### structure

demo ledger setup is divided into `eks-cluster` and `kubernetes` modules. This allows us to manage the eks-cluster separately from applications and services. To proceed through each stage you will move into the respective directory and apply the configuration.

### aws credentials
terraform has been configured to look for aws credentials in the user's home directory ($HOME/.aws) by default. This will normally be set by aws cli when you run `aws configure`. You can tell terraform to look elsewhere for configuration by passing the `tfvar` switch to `terraform apply` like so:

    terraform apply -var="aws_config_dir=/root/secret/stuff/.aws"

In any case, you will be asked to provide aws profile in the following steps.

### aws infrastructure

    cd eks-cluster
    terraform init # if this is your first deployment

As stated under prerequisites, before you apply, you need to put provisioning files in place. terraform will look for them under `provision` folder. You will need a `ledger-provision-response`. See [here](../utilities/README.md) for how to build the `ledger-prosion` binary.

    terraform apply -var-file="../kubernetes/provision/terraform.tfvars"

### ledger workload
Assuming you are in the `eks-cluster` directory, change to the `kubernetes` directory.

    cd ../kubernetes
    terraform init # if this is your first deployment

You will need to populate `tls` directory with `cert.pem`, `key.rsa`. Then, since you already have the provision folder from the previous step, just point terraform at it.

    terraform apply -var-file="provision/terraform.tfvars"

you will be asked for a dockerconfigjson file for registry credentials. Note that your personal credentials will usually not be sufficient. you will be shown a graph of changes and asked to indicate whether you will proceed or exit. It will exit almost immediately, but it will take another 5 minutes or so for all containers to become ready. If you want visible confirmation of readiness, continue to visibility section. Otherwise, you are done.

## troubleshooting

If ledger never becomes ready (client can't connect or correctly formatted transactions are not committed) the usual suspects are user supplied configuration such as docker registry credentials and release version.

## visibility

You can inspect your deployment either through aws eks web interface you using kubectl. Here are instructions for setting up [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/).

First move back to the first terraform module (eks-cluster) and configure kubectl using aws tool:

    aws eks --region us-east-1 update-kubeconfig --name $(terraform output -raw cluster_id)

With kubectl configured you can check that you have nodes registered with eks.

    kubectl get nodes

 You should check your pods are healthy and locate your load-balancer services. The easiest way to interact with kubectl is to change back to `eks-cluster` directory, but you can also configure kubectl to use if from here or however you like.

    cd ../eks-cluster
    kubectl get pods -n election
    kubectl get svc -n election

### tail some logs
simple log aggregation of validators

    kubectl logs -n election statefulset/ledger -c validator

## destroy
First destroy `kubernetes` then the `eks-cluster` if you have manually created in load-balancers of persistent volumes outside of terraform you should delete them before proceeding. Provide the same variables as with `apply`.

    cd kubernetes
    terraform destroy -var-file="provision/terraform.tfvars"
    cd ../eks-cluster
    terraform destroy -var-file="../kubernetes/provision/terraform.tfvars"

## metrics

Influxdb, Grafana and telegraf are included in standered deployment. You can find grafana endpoint for your deployment by what of the service.

    kubectl get svc -n metrics

Use admin:admin for default user and password.

### influxdb time display format

if using the influxdb client for introspection, it may be helpful to set time format:
https://stackoverflow.com/questions/31631645/how-to-format-time-in-influxdb-select-query

## add-ons

You can easily add new workloads to your deployment by downloading their kubernetes manifests and applying them (`kubectl apply -f manifest.yaml`). For inclusing in terraform (standard) deployment, convert them to `tf` files and drop them in the `kubernetes` folder. There is a [convenient tool](https://github.com/sl1pm4t/k2tf) that will do the conversion for you.
