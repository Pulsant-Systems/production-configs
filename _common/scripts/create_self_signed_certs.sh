#!/bin/bash

set -e

CERT_NAME="devel_system"
CERT_PATH="/srv/pulsant/mist/certs"
DAYS_VALID=3650
KEY_SIZE=4096

while getopts "f:p:" arg; do
    case $arg in
	f)
	    CERT_NAME="${OPTARG}"
	    ;;
	p)
            CERT_PATH="${OPTARG}"
            ;;
	\?)
	    echo "Invalid option: -${OPTARG}" >&2
	    exit 1
	    ;;
    esac
done

mkdir -p ${CERT_PATH}
cd ${CERT_PATH}

CONFIG_FILE=$(mktemp /tmp/gen-ssl.XXXXXXXXX.conf)
V3_EXT=$(mktemp /tmp/gen-ssl-v3-ext.XXXXXXXXX.conf)

CN="$(hostname -f)"
# Setup the list of required certs
REQUIRED_CERTS=()
REQUIRED_CERTS+=("${CN}")
REQUIRED_CERTS+=("mist.local")
REQUIRED_CERTS+=("portal.local")
REQUIRED_CERTS+=("mist.$(hostname -f)")
REQUIRED_CERTS+=("portal.$(hostname -f)")

echo "Generating KEY (${KEY_SIZE} bits):"
openssl genrsa -out ${CERT_NAME}.key ${KEY_SIZE}

echo "Creating config file: ${CONFIG_FILE}"

cat <<EOF > ${CONFIG_FILE}
[ req ]
default_bits       = 4096
prompt             = no
distinguished_name = distinguished_name
req_extensions     = req_ext
[ distinguished_name ]
countryName                = GB
stateOrProvinceName        = Berks
localityName               = Reading
organizationName           = Pulsant
commonName                 = ${CN}
[ req_ext ]
subjectAltName = @alt_names
[alt_names]
EOF

COUNT=1
for DNS_ALT in ${REQUIRED_CERTS[@]}; do
    echo "DNS.${COUNT} = ${DNS_ALT}" >> ${CONFIG_FILE}
    COUNT=$((1 + ${COUNT}))
done
echo "IP.1 = $(hostname -i)" >> ${CONFIG_FILE}

cat ${CONFIG_FILE}

echo "Generating CSR for: ${CN}"
openssl req \
	-new \
	-sha256 \
	-key ${CERT_NAME}.key \
	-out ${CERT_NAME}.csr \
	-config ${CONFIG_FILE}

echo "CSR Request"
openssl req -sha256 -in ${CERT_NAME}.csr -text -noout

echo "Generating v3.ext"
cat <<EOF > ${V3_EXT}
# v3.ext
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
EOF
COUNT=1
for DNS_ALT in ${REQUIRED_CERTS[@]}; do
    echo "DNS.${COUNT} = ${DNS_ALT}" >> ${V3_EXT}
    COUNT=$((1 + ${COUNT}))
done
echo "IP.1 = $(hostname -i)" >> ${V3_EXT}

echo "Generating self signed cert"
openssl x509 -req \
	-days ${DAYS_VALID} \
	-sha256 \
	-extfile ${V3_EXT} \
	-in ${CERT_NAME}.csr \
	-signkey ${CERT_NAME}.key \
	-out ${CERT_NAME}.crt

echo "Self signed cert details:"
openssl x509 -in ${CERT_NAME}.crt -text -noout | grep -i "DNS"

# This is the same as the cert because Apache2.2
# See: https://stackoverflow.com/questions/26873612/which-certificate-chain-file-to-include-with-self-signed-certificate
echo "Create server-chain.crt with copy of the cert"
cp ${CERT_NAME}.crt server-chain.crt
