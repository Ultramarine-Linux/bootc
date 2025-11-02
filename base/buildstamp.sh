#!/bin/bash -x

# get data from /etc/os-release

source /etc/os-release


# get date in form of example 202112022224
DATE=$(date +%Y%m%d%H%M)

UUID="${DATE}.$(uname -m)"

# Inject a dummy .buildstamp so Anaconda doesn't complain
cat << EOF > /.buildstamp
[Main]
Product=${NAME}
Version=${VERSION}
BugURL=${BUG_REPORT_URL}
IsFinal=true
UUID=$UUID
Variant=${VARIANT_ID}
[Compose]
Katsu=0.1
EOF
