#!/usr/bin/env bash

# Try creating the DB and user Adaptive Questionnaire expects.
# Try every 5 secs for 10 times at most.
# A bit of a waste if a DB/user is there or it can be created on the
# first attempt, but we can improve this script later.
#
# You've got to set the following env vars before calling this script.
#
# - CONN_URI. Postgres URI to connect to the server as admin user.
#   E.g. CONN_URI=postgresql://admin-user:admin-pass@pg-server
# - AQ_DB. The name of the Adaptive Questionnaire DB. This script
#   will create a DB with the given name. E.g. AQ_DB=adaptive
# - AQ_USER. The Adaptive Questionnaire's DB user. This user will
#   own the Adaptive Questionnaire DB. E.g. AQ_USER=ada
# - AQ_PASS. The password for the above user. E.g. AQ_PASS=yo!
#

for k in 1 2 3 4 5 6 7 8 9 10
do
    echo "attempt #${k}"

    # ignore failure to create db or role, there's no side-effects.
    # (if the db/role is there, then psql returns an error but the
    # cmd does nothing to the existing objects.)

    echo "creating role: ${AQ_USER}"
    psql "${CONN_URI}" -c "create role ${AQ_USER} login password '${AQ_PASS}'"

    echo "creating database: ${AQ_DB}"
    psql "${CONN_URI}" -c "create database ${AQ_DB} owner ${AQ_USER} encoding 'UTF-8'"

    sleep 5
done
