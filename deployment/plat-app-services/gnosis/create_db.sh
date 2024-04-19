#!/usr/bin/env bash

# Try creating the DBs the Profiler app expects.
# Try every 5 secs for 10 times at most.
# A bit of a waste if a DB is there or it can be created on the first
# attempt, but we can improve this script later.
#
# You've got to set a valid connection URI in the CONN_URI env var
# before calling the script, e.g.
#
#     CONN_URI=postgresql://user-who-owns-dbs:user-pass@pg-server
#

for k in 1 2 3 4 5 6 7 8 9 10
do
    echo "attempt #${k}"

    # ignore failure to create db, there's no side-effects.
    # (if the db is there, then psql returns an error but the cmd does
    # nothing to the existing db.)

    echo 'creating database: Knowledge'
    psql "${CONN_URI}" -c 'create database "Knowledge"'

    sleep 5
done
