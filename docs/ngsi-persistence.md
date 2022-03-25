NGSI Persistence
----------------
> Auto-magically stashing away your NGSI entities.

As documented in the architecture, through the dynamic persistence
mechanism we put in place, the platform can acquire data from new
services and devices and then automatically store it in a database
and generate time series out of it **without** having to define a
data schema upfront.

Surely the approach has its own limitations though: 

* It only works for NGSI data — i.e. the new service or device
  "speaks NGSI" natively.
* It can also work if the service/device data gets "translated"
  into NGSI — this typically happens for devices that connect to
  Kitt4sme through FIWARE Agents.
  
But keep in mind in my experience, **arbitrary** device plug-and-play
is a bit of a pipe dream since in practice even if you do things the
FIWARE way, each device typically requires some manual integration
steps — e.g. defining a mapping from device proprietary data format
to NGSI.


### NGSI Context

KITT4SME uses Orion LD as a Context Broker and Mongo DB as a persistence
back end for it. This way, the KITT4SME platform can acquire any NGSI
entity type and automatically store it in Mongo DB without knowing the
exact structure of the data beforehand. This is particularly useful
to connect new services to the platform, since as long as they "speak
NGSI", their data can be automatically stored in a database by the
platform.

This dynamic persistence mechanism is also useful when connecting new
devices to the platform. In fact, if the data produced by a new device
to be connected to the KITT4SME platform can be translated into the NGSI
format (this typically happens through FIWARE Agents), then KITT4SME
can automatically save data coming from that device as soon as the
device is physically connected to the platform.

However, take heed: in practice each device typically requires some
manual integration steps — e.g. defining a mapping from device proprietary
data format to NGSI.

To illustrate the approach, we are going to simulate how a new wearable
device would automatically have Orion LD save its data, using the live
KITT4SME cluster (kitt4sme.collab-cloud.eu). The following HTTP call
simulates the device updating the IoT Context with an NGSI entity
containing heart rate and temperature readings of a factory worker
wearing it.

```console
curl -v kitt4sme.collab-cloud.eu/orion/v2/entities?options=upsert \
     -H 'Content-Type: application/json' \
     -H 'fiware-service: zekis_manufacturing' \
     -d '
{
  "id": "urn:ngsi-ld:zekis:wearable:004",
  "type": "Biometrics",
  "heartRate": {
    "type": "Integer",
    "value": 78
  },
  "temperature": {
    "type": "Number",
    "value": 36.1
  }
}
'
```

Note that the device specifies which platform tenant it belongs in
through the FIWARE service header. Since this is the first time a
device owned by the specified tenant (`zekis_manufacturing`) sends
data to the platform, a new Mongo database is automatically created
for that tenant and then the NGSI entity in the HTTP payload saved
to that database.

The following is a recording of an interactive session with the KITT4SME
Mongo DB instance soon after the device sent its data to Orion LD.
As it can be seen below, a new database named `orion-zekis_manufacturing`
was created and the NGSI entity `urn:ngsi-ld:zekis:wearable:004` was
correctly stored in it.

```console
> show dbs
...
orion-zekis_manufacturing  0.000GB
> use orion-zekis_manufacturing
switched to db orion-zekis_manufacturing
> db.getCollectionNames()
[ "csubs", "entities" ]
> db.entities.find({})
...
{ "id" : "urn:ngsi-ld:zekis:wearable:004", 
  "type" : "Biometrics", "servicePath" : "/" }, 
  "attrNames" : [ "heartRate", "temperature" ],
  "attrs" : { "heartRate" : { "type" : "Integer", "value" : 78 },
  "temperature" : { "type" : "Number", "value" : 36.1, } 
}
...
```


### Time series

In addition to the time series defined for the existing KITT4SME pilot
deployments, the platform can build time series dynamically and on-demand
by tracking IoT Context changes. This feature works similarly to the
dynamic persistence mechanism described earlier for Orion LD.

Specifically, the Quantum Leap service is notified by Orion LD of
changes to the current IoT NGSI context and stores each entity change
in a time-indexed sequence of entity attributes. The original NGSI
entity is flattened into a SQL record by storing each entity attribute
in a table field. The table and its columns are automatically generated
from the KITT4SME tenant name, the NGSI attribute names and types.
Thus, KITT4SME can generate a historical record of NGSI entities even
without knowing in advance the exact structure of the data and who
(tenant) owns it.

The following screenshot shows querying Crate DB to retrieve three
entries of the time series Quantum Leap automatically built out of
changes to the NGSI entity "urn:ngsi-ld:zekis:wearable:004" from the
previous example.

![Querying the time series in Crate DB.][query]




[query]: ./crate-ql-ts-query.png
