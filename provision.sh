#!/usr/bin/bash

BIN_FILE="./ledger-provision"
OUTDIR="./kubernetes/provision"
PROVISION_CMD="${BIN_FILE} ${1} ${OUTDIR}"
export TF_VAR_ledger_hosts="$(${PROVISION_CMD})"
terraform apply
