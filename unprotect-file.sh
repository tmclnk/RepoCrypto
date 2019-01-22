#!/bin/bash

# no other algorithms
algorithm="aes-256-cbc"
removesource=0

help(){
    cat <<EOF 
USAGE
    ${BASH_SOURCE[0]} -keyasplaintext <base64-encoded-key> <file>

DESCRIPTION
    Decrypts an AES-256 encrypted file whose contents are, in order:
    4 bytes Initialization Vector (IV) length, little-endian binary, then
    the actual IV,then the AES-256 encoded data.

REQUIREMENTS
    bash openssl xxd bc awk base64

OPTIONS
    -k|-keyasplaintext     a base64 encoded key
    -removesource       remove the original file after decrypting
EOF
    exit 0
}

# make sure we have all these commands available
for cmd in openssl xxd bc awk base64
do
    if [ ! -x "$(command -v $cmd)" ]; then
        >&2 echo "ERROR: $cmd is required"
        exit 1
    fi
done

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -k|-keyasplaintext)
    # assume the key is base64 encoded and convert it to a single line of hex
    base64key=$2
    shift # past argument
    shift # past value
    ;;
    -removesource)
    removesource=1
    shift
    ;;
    -help)
    help
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters
file="$1"

if [ -z "$file" ]; then
    >&2 echo "ERROR: File argument is required" 
    help
    exit 1
fi
if [ ! -f "$file" ]; then
    >&2 echo "ERROR: File '$file' not found"
    exit 1
fi
if [ -z "$base64key" ];then
    >&2 echo "ERROR: key is required" 
    help
    exit 1
fi


# force .AES naming convention.  this is a pedantic choice but it 
# makes this whole package more consistent
if [ ! ${file: -4} == ".AES" ]; then
    >&2 echo "ERROR: Filename must end in .AES"
    exit 1
fi

# key is base64, need to get it as hex
# assume key is in $key
hexkey=$(echo "$base64key" | base64 -d | xxd -p | tr -d '\n')

# first 4 bytes specifies length of the IV, but it's little endian
# and we need it as decimal
ivlen=$(( 16#$(xxd -l 4 -e "$file" | awk '{print $2}'))) 

# next 16 bytes is the IV itself
# after that is the encrypted data
tmpfile=$(mktemp)
trap "rm $tmpfile" EXIT
dd iflag=skip_bytes skip=$(( 4 + $ivlen )) if=$file of=$tmpfile > /dev/null 2>&1

# the initialization vector has a hex string
ivhex=$(xxd -s 4 -l $ivlen -p "$file")

# use openssl to do the decrypt
openssl enc -d -"$algorithm" -K "$hexkey" -iv "$ivhex" -in $tmpfile > ${file%.AES}

if [ \( $? -eq 0 \) -a \( $removesource -eq 1 \) ]; then
    rm $file
fi

exit 0
