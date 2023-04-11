Insight Tiny Test Env
---------------------

Bare-bones setup to simulate Insight sending data to Orion and then
have the Insight dashboard display that data.

Run the Docker Compose file in this dir

```bash
$ docker compose up -d
```

Send an Insight NGSI entity to Orion

```bash
$ ./upsert-entity.sh
```

Go check out the Insight dashboard at

- http://localhost:8000/dazzler/csic/-/insight/

Clean up

```bash
$ docker compose down -v
```
