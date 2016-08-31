#!/bin/bash
# Reencrypts SSH private keys using 3DES in a PKCS#8 container

set -o errexit;
set -o nounset;

if [ -z "$1" ]; then
        echo "Usage: $0 </path/sshkey.private>";
        exit 1;
fi
umask 0077
mv "$1" "$1.old"
openssl pkcs8 -topk8 -v2 des3 -in "$1.old" -out "$1"
rm "$1.old"
