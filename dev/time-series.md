Time series Docker env
----------------------
> Simple Docker compose env to play with time series.

In the box:

* CrateDB
* Postgres + Timescale & Postgis extensions
* QuantumLeap configured with a Redis cache and Postgres as default DB

Easy to bolt on:

* Route some of the QuantumLeap data to CrateDB

Example usage:

```bash
$ docker compose -f time-series.compose.yaml up -d
$ curl localhost:8668/v2/notify -H 'Content-Type: application/json' -d @foobie.json
$ psql postgres://quantumleap:*@localhost -c 'select * from etfoo'
```

should print the data of the entity in `foobie.json` that `curl` POSTed
to QuantumLeap.

With this basic setup, any entity you POST to QuantumLeap will end up
in Postgres. But it's easy to have QuantumLeap use CrateDB for some
of your data, depending on tenant (FIWARE service). All you need to
do is mount a config file on the QuantumLeap Docker service. Details
over here:

* https://quantumleap.readthedocs.io/en/latest/admin/configuration/

(Read the database selection section.)
