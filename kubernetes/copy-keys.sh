#!/bin/sh

set -ex

ls /mnt/allkeys/
SET_INDEX=${HOSTNAME##*-};
echo "Starting initializing for pod $SET_INDEX"
cp /mnt/allkeys/validator_${SET_INDEX}.priv /mnt/node/validator.priv
cp /mnt/allkeys/validator_${SET_INDEX}.pub /mnt/node/validator.pub
cp /mnt/allkeys/ledger-node-http-digital-signature_${SET_INDEX}.priv.pem \
   /mnt/http/ledger-node-http-digital-signature.priv.pem
cp /mnt/allkeys/ledger-node-http-digital-signature_${SET_INDEX}.crt.pem \
   /mnt/http/ledger-node-http-digital-signature.crt.pem
cp /mnt/allkeys/ledger-node-http-digital-signature_${SET_INDEX}.chain.pem \
   /mnt/http/ledger-node-http-digital-signature.chain.pem

# FIXME we need to use names from variables
# so this file needs to be generated
