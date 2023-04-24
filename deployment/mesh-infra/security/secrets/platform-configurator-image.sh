#!/usr/bin/env bash

#
# Generate a SealedSecret for pulling the Platform Configurator
# image.
# Usage:
#
#   $ ./platform-configurator.sh TokenYouGotFromSUPSI
#
# where the argument is a GitLab token SUPSI gave you that includes
# a permission to pull images from https://gitlab-core.supsi.ch:5050.
#
# Notice `kubeseal` needs to be able to access the cluster for this
# script to work. You can also work offline if you like, but you'll
# have to fetch the controller pub key with `kubeseal --fetch-cert`
# beforehand. Read the Sealed Secrets docs for the details.
#

set -e

GITLAB_USR="gitlab+deploy-pc-k4s-cloud"
GITLAB_TOKEN=$1

kubectl create secret docker-registry platform-configurator-image \
        --docker-server="https://gitlab-core.supsi.ch:5050" \
        --docker-username="${GITLAB_USR}" \
        --docker-password="${GITLAB_TOKEN}" \
        -o yaml --dry-run='client' | \
    sed 's!^  creationT.*$!  namespace: default\n  annotations:\n    sealedsecrets.bitnami.com/managed: "true"!' | \
    kubeseal -o yaml -w platform-configurator-image.yaml
