#!/bin/bash
# Script to fetch the latest Debian 13 ISO details (URL and checksum)
set -e

DEBIAN_MIRROR="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/"
DYNAMIC_VARS_FILE="./vars/generated-debian13-vars.pkrvars.hcl"

ISO_FILE=$(curl -s ${DEBIAN_MIRROR} | grep -oP 'debian-13\.\d+\.\d+-amd64-netinst\.iso' | head -n1)
if [ -z "$ISO_FILE" ]; then
    echo 'ERROR: Could not detect Debian 13 ISO on remote Debian repository.';
    exit 1;
fi

ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/$ISO_FILE"

# Fetch matching SHA512 checksum
SHA512=$(curl -s ${DEBIAN_MIRROR}SHA512SUMS | grep "$ISO_FILE" | awk '{print $1}')

if [ -z "$SHA512" ]; then
    echo 'ERROR: Could not pick up SHA512 checksum on remote Debian repository.';
    exit 1;
fi

echo "dynamic_iso_url = \"$ISO_URL\"" >  ${DYNAMIC_VARS_FILE}
echo "dynamic_iso_checksum = \"sha512:${SHA512}\"" >> ${DYNAMIC_VARS_FILE}
#echo "locals { dynamic_file_name = \"$ISO_FILE\" }" >> ${DYNAMIC_VARS_FILE}

echo "Fetched latest Debian 13 ISO details:"
echo "ISO URL: $ISO_URL"
echo "SHA512: $SHA512"
echo "Details written to ${DYNAMIC_VARS_FILE}"
exit 0
