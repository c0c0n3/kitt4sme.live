#!/usr/bin/env bash

#
# Env vars to keep our scripts tidy and avoid repetition.
#

set -e

# Command to open a browser window to navigate to a given URL.
# The default command opens your fave browser on MacOS, change it to
# suit your box's env / taste. E.g. if you have Firefox, you could set
# a value of: firefox.
OPEN_URL_CMD=open

# The IP or hostname to access the cluster.
K4S_CLUSTER=192.168.64.20

# The URLs to navigate to the ArgoCD, Crate, and Grafana UIs.
K4S_ARGOCD_URL="http://${K4S_CLUSTER}:8080"
K4S_CRATE_URL="http://${K4S_CLUSTER}:4200"
K4S_GRAFANA_URL="http://${K4S_CLUSTER}:3000"

# Orion and QuantumLeap endpoints.
K4S_ORION="http://${K4S_CLUSTER}:1026"
K4S_QUANTUMLEAP="http://${K4S_CLUSTER}:8668"
# K4S_ORION="http://${K4S_CLUSTER}/orion"
# K4S_QUANTUMLEAP="http://${K4S_CLUSTER}/quantumleap"
