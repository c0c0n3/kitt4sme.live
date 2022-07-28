#!/usr/bin/env bash

#
# Generate a SealedSecret for pulling the Insight Generator image.
# Usage:
#
#   $ ./insight-image.sh PATyouGotFromCSIC
#
# where the argument is a GitHub PAT avillaj1988 gave you that
# includes a permission to pull images from https://ghcr.io/avillaj1988.
#
# Notice `kubeseal` needs to be able to access the cluster for this
# script to work. You can also work offline if you like, but you'll
# have to fetch the controller pub key with `kubeseal --fetch-cert`
# beforehand. Read the Sealed Secrets docs for the details.
#

set -e

GITHUB_USR=avillaj1988
GITHUB_PAT=$1

kubectl create secret docker-registry insight-image \
        --docker-server="https://ghcr.io" \
        --docker-username="${GITHUB_USR}" \
        --docker-password="${GITHUB_PAT}" \
        -o yaml --dry-run='client' | \
    sed 's!^  creationT.*$!  namespace: default\n  annotations:\n    sealedsecrets.bitnami.com/managed: "true"!' | \
    kubeseal -o yaml -w insight-image.yaml
