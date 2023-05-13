#!/usr/bin/bash

BLOCK_SINGER_PRIV="ledger-node-auth-digital-signature.priv.pem"

ELECTION_LIST_FILE=${1}
if [ ! -f "${ELECTION_LIST_FILE}" ]; then
    echo "election-list not found."
    exit
fi

WORKDIR=$(dirname ${ELECTION_LIST_FILE})
echo $WORKDIR

# TODO set this as TF VAR
NODE_COUNT=$(jq '.elections[0].network.ledger.nodes|length' < ${ELECTION_LIST_FILE})

# jq '.elections[0].network.ledger.nodes[].endpoint' < election-list.json

ENDPOINTS=$(jq '.elections[0].network.ledger.nodes[].endpoint' < ${ELECTION_LIST_FILE})


for url in ${ENDPOINTS[@]}; do
    NODEDIR=$(echo $url |sed 's/https\?:\/\///'| tr -d \" | tr '[:upper:]' '[:lower:]')
    echo "${WORKDIR}/${NODEDIR}"
    if [ -d "${WORKDIR}/${NODEDIR}" ]; then
        ls "${WORKDIR}/${NODEDIR}"
        # verify against:
        # openssl ec -in private-key.pem -no_public| openssl asn1parse
        # c15629243a4bf47422228b3c9475d26f9a038ad77329057f6729b16dd17ced4f
        # you can also print priv and ext pub key:
        # openssl ec -in private-key.pem -noout -text
        openssl ec -in "${WORKDIR}/${NODEDIR}/${BLOCK_SINGER_PRIV}" -no_public -outform DER \
            | tail -c +8 | head -c 32 | xxd -p -c 32

        # dtool gen pub key from priv
        # dtool ec_pk -c secp256k1 -s 0xc15629243a4bf47422228b3c9475d26f9a038ad77329057f6729b16dd17ced4f
        # 0x04e8350337061b41d0e82250ca492e794800cae6785c2fc87057c4bea9db74c97c9ddf87d094370499d9bd21cbf48ca738f7be42664000ff2afc8abf78accf24b3
        # openssl gen pub key from priv
        # openssl ec -in provision/nodey.example.com/ledger-node-auth-digital-signature.priv.pem -pubout  -outform DER   | tail -c +24 | xxd -p -c 65
        # dtool gen compressed pub key from priv
        # dtool ec_pk -c secp256k1 -s 0xc15629243a4bf47422228b3c9475d26f9a038ad77329057f6729b16dd17ced4f -C
        # 0x03e8350337061b41d0e82250ca492e794800cae6785c2fc87057c4bea9db74c97c
        # openssl gen compressed pub key from priv
        # openssl ec -in provision/nodey.example.com/ledger-node-auth-digital-signature.priv.pem -pubout -conv_form compressed -outform DER   | tail -c +24 | xxd -p -c 65
        # TODO copy stuff from each folder
    fi
done

# TODO call terraform apply


# 3056301006072a8648ce3d020106052b8104000a034200|04e8350337061b
# 41d0e82250ca492e794800cae6785c2fc87057c4bea9db74c97c9ddf87d0
# 94370499d9bd21cbf48ca738f7be42664000ff2afc8abf78accf24b3
