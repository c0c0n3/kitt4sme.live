Orion subs
----------

Some quick shell commands to set up Orion subs. Keep in mind it's best
to do that in Python with FiPy actually.


### CSIC tenant

Show subs.

```bash
$ curl -v http://kitt4sme.collab-cloud.eu/orion/v2/subscriptions \
       -H 'fiware-service: csic'
```

Subscribe QL and Roughnator.

```bash
$ curl -v http://kitt4sme.collab-cloud.eu/orion/v2/subscriptions \
       -H 'fiware-service: csic' \
       -H 'Content-Type: application/json' \
       -d @quantumleap.subscription.json

$ curl -v http://kitt4sme.collab-cloud.eu/orion/v2/subscriptions \
       -H 'fiware-service: csic' \
       -H 'Content-Type: application/json' \
       -d @roughnator.subscription.json 
```


### Ideal Tek tenant

Show subs.

```bash
$ curl -v http://kitt4sme.collab-cloud.eu/orion/v2/subscriptions \
       -H 'fiware-service: itek'
```

Subscribe QL.

```bash
$ curl -v http://kitt4sme.collab-cloud.eu/orion/v2/subscriptions \
       -H 'fiware-service: itek' \
       -H 'Content-Type: application/json' \
       -d @quantumleap.subscription.json

$ curl -v http://kitt4sme.collab-cloud.eu/orion/v2/subscriptions \
       -H 'fiware-service: csic' \
       -H 'Content-Type: application/json' \
       -d @roughnator.subscription.json 
```
