#!/usr/bin/bash

set -ex

printenv

cp /mnt/config/validator.toml /etc/sawtooth/validator.toml

[[ `hostname` =~ -([0-9]+)$ ]] || exit 1
ordinal=${BASH_REMATCH[1]}
if [[ $ordinal -eq 0 ]]; then

  rm -f /var/lib/sawtooth/genesis.batch
  # intialized chain + genesis batch will crash validator
  # so we check if for a block-chain-id
  if [[ ! -f /var/lib/sawtooth/block-chain-id ]]; then
      cp /mnt/genesis/genesis.batch /var/lib/sawtooth/genesis.batch
  fi

  sawtooth-validator -v \
    --endpoint tcp://ledger-0.votingapp.election.svc.cluster.local:8800 \
    --bind component:tcp://eth0:4004 \
    --bind network:tcp://eth0:8800 \
    --bind consensus:tcp://eth0:5050 \
    --peers tcp://ledger-1.votingapp.election.svc.cluster.local:8800 \
    --peers tcp://ledger-2.votingapp.election.svc.cluster.local:8800 \
    --peers tcp://ledger-3.votingapp.election.svc.cluster.local:8800 \
    --peers tcp://ledger-4.votingapp.election.svc.cluster.local:8800
fi
if [[ $ordinal -eq 1 ]]; then
  sawtooth-validator -v \
    --endpoint tcp://ledger-1.votingapp.election.svc.cluster.local:8800 \
    --bind component:tcp://eth0:4004 \
    --bind network:tcp://eth0:8800 \
    --bind consensus:tcp://eth0:5050 \
    --peers tcp://ledger-0.votingapp.election.svc.cluster.local:8800 \
    --peers tcp://ledger-2.votingapp.election.svc.cluster.local:8800 \
    --peers tcp://ledger-3.votingapp.election.svc.cluster.local:8800 \
    --peers tcp://ledger-4.votingapp.election.svc.cluster.local:8800
fi
if [[ $ordinal -eq 2 ]]; then
  sawtooth-validator -v \
    --endpoint tcp://ledger-2.votingapp.election.svc.cluster.local:8800 \
    --bind component:tcp://eth0:4004 \
    --bind network:tcp://eth0:8800 \
    --bind consensus:tcp://eth0:5050 \
    --peers tcp://ledger-0.votingapp.election.svc.cluster.local:8800 \
    --peers tcp://ledger-1.votingapp.election.svc.cluster.local:8800 \
    --peers tcp://ledger-3.votingapp.election.svc.cluster.local:8800 \
    --peers tcp://ledger-4.votingapp.election.svc.cluster.local:8800
fi
if [[ $ordinal -eq 3 ]]; then
  sawtooth-validator -v \
    --endpoint tcp://ledger-3.votingapp.election.svc.cluster.local:8800 \
    --bind component:tcp://eth0:4004 \
    --bind network:tcp://eth0:8800 \
    --bind consensus:tcp://eth0:5050 \
    --peers tcp://ledger-0.votingapp.election.svc.cluster.local:8800 \
    --peers tcp://ledger-1.votingapp.election.svc.cluster.local:8800 \
    --peers tcp://ledger-2.votingapp.election.svc.cluster.local:8800 \
    --peers tcp://ledger-4.votingapp.election.svc.cluster.local:8800
fi
if [[ $ordinal -eq 4 ]]; then
  sawtooth-validator -v \
    --endpoint tcp://ledger-4.votingapp.election.svc.cluster.local:8800 \
    --bind component:tcp://eth0:4004 \
    --bind network:tcp://eth0:8800 \
    --bind consensus:tcp://eth0:5050 \
    --peers tcp://ledger-0.votingapp.election.svc.cluster.local:8800 \
    --peers tcp://ledger-1.votingapp.election.svc.cluster.local:8800 \
    --peers tcp://ledger-2.votingapp.election.svc.cluster.local:8800 \
    --peers tcp://ledger-3.votingapp.election.svc.cluster.local:8800
fi

# FIXME uris should use node endpoints from election-object
# instead of internal uris. So we need to generate this.
