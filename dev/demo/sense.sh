#!/usr/bin/env bash

#
# Send values from a fictitious CSIC machine to Orion every second.
# (Use `Ctrl c` to stop.) Generate random integers between 1 and 10
# for Ra attribute in `machine.json`.
#


print_header () {
    echo "======================================================================="
    echo "        $1"
    echo "======================================================================="
}

set -e

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${SCRIPTSDIR}/env.sh"


cnt=0
while true
do
    print_header "Sending random Ra values from CSIC lab."

    Ra=$((1 + $RANDOM % 10))
    entity=$(sed "s/-123/${Ra}.1/" ${SCRIPTSDIR}/machine.json)

    echo ${entity} | \
        curl -v "${K4S_ORION}/v2/entities" \
             -H 'Content-Type: application/json' \
             -H 'fiware-service: csic' \
             -d@-

#    echo ${entity} | \
#    curl -v "${K4S_ORION}/ngsi-ld/v1/entities" \
#         -H 'Content-Type: application/ld+json' \
#         -H 'fiware-service: csic' \
#         -d@-

    cnt=$((cnt+1))
    print_header "Readings sent so far: ${cnt}"

    sleep 1
done
