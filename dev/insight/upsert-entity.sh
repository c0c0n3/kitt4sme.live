#!/usr/bin/env bash

curl -v localhost:1026/v2/entities?options=upsert \
     -H 'fiware-service: csic' \
     -H 'fiware-servicepath: /' \
     -H 'Content-Type: application/json' \
     -d @insight-entity.json
