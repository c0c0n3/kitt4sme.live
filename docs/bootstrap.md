Cluster Bootstrap
-----------------
> One-off procedure to build & set up your KITT4SME infrastructure.

## Table Of Contents

- Introduction
- Docker compose based KITT4SME platform
  - QuantumLeap subscription to the Orion Context Broker
  - NGSI payloads
  - Roughnator example
  
 - Kubernetes based KITT4SME platform
    - Preparing your own fork
    - Tools
    - Cluster orchestration
    - Mesh infra
    - Continuous delivery
    - Post-install steps
---

### Introduction

Hello. In this page you will find the basic content to make your AI solution part of the KITT4SME platform. Additionally you will links to to the rest of the documentation will more detailed information for each topic.

The things you have to do are the following:

1. Your AI solution must be a docker image. It may be a RESTful web application or any other app that runs indefinitely. 
2. Initially you will integrate it with the stripped down version of the KITT4SME platform
3. Your AI solution must be able to interact with the Orion Context Broker and/or the data sources.
4. Create a subscription to the Orion Context Broker, in order it to push the data to the QuantumLeap. 
5. Run and end to end scenario, and make sure that everything works as expected.
6. The solution will be a member of a Kubernetes cluster, as part of the full KITT4SME solution 

### Docker compose based KITT4SME platform

Initially you will work the stripped down docker based version of the KITT4SME platform. You can use the provided docker compose code below that includes the FIWARE stack (Orion Context Broker, QuantumLeap, CrateDb and CrateDb initiation script), and the only thing you have to do is to include your AI dockerized service in the file.

If you want to deploy you application in a different way, it is fine. 

```
version: '3.9'

services:
  
  # Here add your AI service
  
  mongodb:
    container_name: mongodb
    restart: always
    volumes:
      - ./mongo-volume:/data/db
    image: mongo:4.4
    networks:
      - k4smenetwork

  orion:
    container_name: orion
    restart: always
    image: fiware/orion-ld:0.8.0
    entrypoint: orionld -fg -multiservice -ngsiv1Autocast -dbhost mongodb -logLevel DEBUG
    networks:
      - k4smenetwork
    ports:
      - "1026:1026"
    depends_on:
      - mongodb

  crate:
    container_name: crate

    image: crate:4.5.1
    command: crate -Cauth.host_based.enabled=false -Ccluster.name=democluster -Chttp.cors.enabled=true -Chttp.cors.allow-origin="*"
    volumes:
      - ./cratedb-volume:/data
    ports:
      - "4200:4200"
      - "4300:4300"
    networks:
      - k4smenetwork

  quantumleap:
    container_name: quantumleap
    restart: always
    image: orchestracities/quantumleap:0.8.3
    depends_on:
      - crate
    networks:
      - k4smenetwork
    ports:
      - "8668:8668"
    environment:
      - QL_DEFAULT_DB=crate
      - CRATE_HOST=crate
      - USE_GEOCODING=False
      - CACHE_QUERIES=False
      - LOGLEVEL=DEBUG

networks:
  k4smenetwork:
    driver: bridge
```

#### QuantumLeap subscription to the Orion Context Broker

In order the QuantumLeap to subscribe to the Orion Context Broker you have to execute the following POST request

```
POST http://localhost:1026/v2/subscriptions

{
  "description": "All entities subscription",
  "subject": {
    "entities": [
      {
        "idPattern": ".*"
      }
    ]
  },
  "notification": {
    "http": {
      "url": "http://localhost:8668/v2/notify"
    }
  },
  "expires": "2040-01-01T14:00:00.00Z"
}
```

You can use curl or POSTMAN, or any tool you like. 

Let's break down the request above:

- **Method**: POST
- **Orion Context Broker url**: http(s)://{whatever is here}:1026/v2/subscriptions. The Orion Context Broker listens by default to the 1026 port.
- **idPattern**: The pattern that filters the needed entities based on their ids. In our case we will leave the wildcard as it is.
- **notification url**: The quantumleap url. QuantumLeap listens by default to the 8668 port.
- **expires**: The subscription expiration date. Set something that expires years later

For more, study the following:

- [https://github.com/c0c0n3/kitt4sme/blob/master/arch/fw-middleware/ngsi-services.md](https://github.com/c0c0n3/kitt4sme/blob/master/arch/fw-middleware/ngsi-services.md)

- [https://github.com/c0c0n3/kitt4sme/blob/master/arch/fw-middleware/ctx-change-propagation.md](https://github.com/c0c0n3/kitt4sme/blob/master/arch/fw-middleware/ctx-change-propagation.md)

- [https://github.com/c0c0n3/kitt4sme/blob/master/arch/fw-middleware/time-series.md](https://github.com/c0c0n3/kitt4sme/blob/master/arch/fw-middleware/time-series.md)

- [https://github.com/c0c0n3/kitt4sme.live/blob/main/docs/ngsi-persistence.md](https://github.com/c0c0n3/kitt4sme.live/blob/main/docs/ngsi-persistence.md)

- [https://www.fiware.org/](https://www.fiware.org/)


#### NGSI payloads

In relation to KITT4SME workflow, the platform is expected to be able to acquire data from the following data sources: 
- The shop floor through a diverse range of Internet of Things (IoT) devices 
- Cyber-physical systems such as wearable devices, environmental sensors, cameras and robots.

Thus, for the sake of interoperability, the data must be defined as NGSI payloads. The NGSI payloads are pushed from the data sources and/or your AI solution to the Orion Context Broker

Each IoT device or robot typically produces raw data (e.g. a temperature reading) in a proprietary format which may vary over time even within the same device (e.g., think of a firmware upgrade) and a similar degree of data format volatility can be expected of information systems (e.g., think of a database schema change). Thus, to acquire data from those environments, a plethora of diverse data formats will need to be understood by the platform, at least at its boundary where information is exchanged with external systems. Moreover, new formats may have to be accommodated as shop floors are connected to the platform. The same line of reasoning applies to data semantics too as the structure and interpretation of the data has to be known by platform components which extract information from those data.

We begin with the elements of the data model which allow to encode objects (concepts, things, etc.) and relationships among them. The `Entity` data
structure identifies a certain concept of interest in a model and describes its properties. Each `Entity` object must have an `id` field containing
a URI that uniquely identifies it and a `type` field to classify the object. 

An `Entity` contains one or more `Attribute`s, each with a `value` and a `type` field. The `value` field holds the actual value of an object's
property whereas the `type` field contains a text label which specifies the data type of that value. When processing an entity, some FIWARE components
attempt to interpret an attribute's value according to the type label, thus it is important to use a label suitable for the value at hand. Most
FIWARE components support boolean types (`type = Boolean`), numeric types (`Integer`, `Float`, `Number`), text (`String`, `Text`), time (`Date`,
`Time`, `DateTime`), geometry (points, lines, etc.), arrays (`Array`) and instances of arbitrary data structures (`StructuredValue`). 

Additionally, an attribute having a type of `Relationship` is interpreted as a pointer
to other entities and its `value` should be one or more URIs identifying other entities in the system. Thus, these "Relation" attributes play a
special role among attributes in that they allow to encode an entity graph where nodes are `Entity` instances and edges are Relation attributes.

FIWARE services exchange data by means of JSON documents. Each `Entity` instance is encoded as a JSON `object` with `id` and `type` `string` fields
and an `object` field in correspondence of each `Attribute`. By way of example, the JSON document below encodes an instance of a milling machine
entity owned by a company named Smithereens. One attribute of this entity is the temperature of the machine's spindle and the other is a pointer to
a separate entity representing the shop floor where the milling machine is located.

```json
{
    "id": "urn:ngsi-ld:smithereens:MillingMachine:1f3d-8776-a3d5-671b",
    "type": "MillingMachine",
    "spindleTemperature": {
        "type": "Float",
        "value": 64.8
    },
    "refShopFloor": {
        "type": "Relationship",
        "value": "urn:ngsi-ld:smithereens:ShopFloor:2"
    }
}
```

Another special kind of attribute is the "Metadata" attribute which can be nested inside an attribute to convey additional information about the
attribute's value. The JSON fragment below contains the same `spindleTemperature` attribute from the previous example but with two
additional metadata fields to provide an accuracy rating for the measured temperature and a timestamp indicating when the reading was taken.

```json
{
    ...
    "spindleTemperature": {
        "type": "Float",
        "value": 64.8
        "metadata": {
            "accuracy": {
                "value": 2,
                "type": "Number"
            },
            "timestamp": {
                 "value": "2021-04-12T07:20:27.378Z",
                 "type": "DateTime"
            }
        }
    }
    ...
}
```

For more, study the following:

- [https://github.com/c0c0n3/kitt4sme/blob/master/arch/fw-middleware/data.md](https://github.com/c0c0n3/kitt4sme/blob/master/arch/fw-middleware/data.md)

- [https://github.com/c0c0n3/kitt4sme.roughnator/blob/main/roughnator/ngsy.py](https://github.com/c0c0n3/kitt4sme.roughnator/blob/main/roughnator/ngsy.py)

- [KITT4SME existing NGSI payloads](https://github.com/c0c0n3/kitt4sme.live/issues/72#issuecomment-1019972046)

- [https://fiware-tutorials.readthedocs.io/en/stable/getting-started/](https://fiware-tutorials.readthedocs.io/en/stable/getting-started/)


#### Roughnator example

The Roughnator is a live simulator that simulates a live environment like the one of the KITT4SME cluster.
Before running your solution, you can run the Roughnator, to understand more how the stripped down version works

[https://github.com/c0c0n3/kitt4sme.roughnator/](https://github.com/c0c0n3/kitt4sme.roughnator/)

----

### Kubernetes based KITT4SME platform

We're going to put together a single-node MicroK8s cluster to host the KITT4SME platform that you, as an open call developer, will use to integrate your solution. We use [MicroK8s][mk8s] so we can start small but then easily add more nodes in the future if needed. You need to provision some hardware to run the KITT4SME platform. The specs are the following 
- At least 8 CPUs, 
- 16GB RAM/4GB swap, 
- 120GB storage. 

Once you've are done with the hardware, you'll have to install Ubuntu 20.04.1 LTS (GNU/Linux 5.4.0-42-generic x86_64) on it. **Please install the exact version mentioned here.**
If you just want to try out the platform quickly, you can spin up an Ubuntu 20.04 VM in no time with Multipass, e.g.

```bash
$ multipass launch --name kitt4sme --cpus 2 --mem 4G --disk 40G 20.04
$ multipass shell kitt4sme
```

and then follow the instructions below. Keep in mind, depending on what you'll do with your platform later, you might need more RAM and storage.

#### Preparing your own fork

The first step is to fork `kitt4sme.live` on GitHub so you can use your fork as a GitOps source for building your cluster. Then in your fork edit

* `deployment/mesh-infra/argocd/projects/base/app.yaml`

to set the URL of your GitHub fork in the `repoURL` field. This will
make Argo CD (see below) source the cluster build instructions from
your repo instead of https://github.com/c0c0n3/kitt4sme.live. For
example, if your GitHub user is `jimbo`

```yaml
  source:
    repoURL: https://github.com/jimbo/kitt4sme.live
    targetRevision: open-calls
    #...other fields
```

Notice the `targetRevision` field specifies which branch to use in your repo. Keep `open-calls` for the bootstrap procedure and change it later if you'd like to use a different branch instead. When done, commit your changes and push upstream to your fork.

#### Tools

We'll use [Nix][nix] to avoid polluting the Ubuntu box with extras.
Install with

```bash
$ sh <(wget -qO- https://nixos.org/nix/install)
```

The script should output a message like

> Installation finished!  To ensure that the necessary environment
> variables are set, either log in again, or type
>
> . /home/ubuntu/.nix-profile/etc/profile.d/nix.sh

Your path to `nix.sh` will likely be different from the above, just
copy-paste and run what the script says.

##### Note
* Always install the latest Nix. At the moment the latest version
  is `2.4`. You might install a newer version when you read this,
  but that's fine too.

Enable Nix flakes

```bash
$ mkdir -p ~/.config/nix
$ echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

There's a basic Nix flake in our repo we'll use to drop into a Nix
shell with the specific versions of the tools we need to manage the
cluster — e.g. `istioctl 1.11.4`. Let's create a convenience script
to start a Nix shell with our flake:

```bash
$ echo 'nix shell github:c0c0n3/kitt4sme.live?dir=nix' > ~/tools.sh
$ chmod +x ~/tools.sh
```

Notice our tools will only be available inside the Nix shell and will
be gone on exiting the shell. In particular, they won't override any
existing tool installation on this box. No dependency hell. But still
inside the Nix shell, you'll get the right version of each tool.


#### Cluster orchestration

We'll use [MicroK8s][mk8s] as a cluster manager and orchestration.
(Read the [Cloud instance][arch.cloud] section of the architecture
document about it.)

Install MicroK8s (upstream Kubernetes 1.21)

```bash
$ sudo snap install microk8s --classic --channel=1.21/stable
```

Add yourself to the MicroK8s group to avoid having to `sudo` every
time your run a `microk8s` command

```bash
$ sudo usermod -a -G microk8s $(whoami)
$ newgrp microk8s
```

and then wait until MicroK8s is up and running

```bash
$ microk8s status --wait-ready
```

Finally bolt on DNS and local storage

```bash
$ microk8s enable dns storage
```

Wait until all the above extras show in the "enabled" list

```bash
$ microk8s status
```

##### Notes
- *Istio*. Don't install Istio as a MicroK8s add-on, since MicroK8s
  will install Istio 1.5, which is ancient!
- *Storage*. MicroK8s comes with its own storage provider
  (`microk8s.io/hostpath`) which the storage add-on enables
  as well as creating a default K8s storage class called
  `microk8s-hostpath`.


Now we've got to [broaden MicroK8s node port range][mk8s.port-range].
This is to make sure it'll be able to expose any K8s node port we're
going to use.

```bash
$ nano /var/snap/microk8s/current/args/kube-apiserver
# add this line
# --service-node-port-range=1-65535

$ microk8s stop
$ microk8s start
```

Since we're going to use vanilla cluster management tools instead of
MicroK8s wrappers, we've got to link up MicroK8s client config where
`kubectl` expects it to be:

```bash
$ mkdir -p ~/.kube
$ ln -s /var/snap/microk8s/current/credentials/client.config ~/.kube/config
```

Now if you drop into the Nix shell, you should be able to access the
cluster with plain `kubectl`. As a smoke test, try

```bash
$ ~/tools.sh
$ kubectl version
$ kubectl get all --all-namespaces
```

Don't exit the Nix shell as we'll need some of the tools for the rest
of the bootstrap procedure.


#### Mesh infra

[Istio][istio] will be our mesh infra software. (If you're not sure
what that means, go read the [Cloud instance][arch.cloud] section of
the architecture document :-)

Deploy Istio to the cluster using our own profile. To do that first
clone your fork and checkout the `open-calls` branch. For example,
if your GitHub user is `jimbo`

```bash
$ git clone https://github.com/jimbo/kitt4sme.live
$ cd kitt4sme.live
$ git checkout open-calls
```

The repo contains the profile you need. Install it with

```bash
$ istioctl install -y --verify -f deployment/mesh-infra/istio/profile.yaml
```

Platform infra services (e.g. FIWARE) as well as app services (e.g.
AI) will sit in K8s' `default` namespace, so tell Istio to auto-magically
add an Envoy sidecar to each service deployed to that namespace

```bash
$ kubectl label namespace default istio-injection=enabled
```

Now go edit the K8s secrets in

- `deployment/mesh-infra/security/secrets.plain`

to enter passwords for ArgoCD, Postgres and Mosquitto. Then, from the
repo's root dir, run

```bash
$ kubectl apply -f deployment/mesh-infra/argocd/namespace.yaml
$ kustomize build deployment/mesh-infra/security/secrets.plain | \
    kubectl apply -f -
```

to stash away your secrets in the cluster. Notice for Open Calls we
manage secrets manually, outside of the ArgoCD GitOps pipeline.


#### Continuous delivery

[Argo CD][argocd] will be our declarative continuous delivery engine.
(Read the [Cloud instance][arch.cloud] section of the architecture
document about our IaC approach to service delivery.) Except for the
things listed in this bootstrap procedure, we declare the cluster
state with YAML files that we keep in the `deployment` dir within
[our GitHub repo][kitt4sme.live]. Argo CD takes care of reconciling
the current cluster state with what we declared in the repo.

For that to happen, we've got to deploy Argo CD and tell it to use
the YAML in your repo to populate the cluster. Your repo also contains
the instructions for Argo CD to manage its own deployment state as
well as the rest of the KITT4SME platform — I know, it sounds like
a dog chasing its own tail, but it works. So we can just build the
YAML to deploy Argo CD and connect it to your repo like this

```bash
$ kustomize build deployment/mesh-infra/argocd | kubectl apply -f -
```

After deploying itself to the cluster, Argo CD will populate it with
all the K8s resources we declared in our repo and so slowly the KITT4SME
platform instance will come into its own. This will take some time.
Go for coffee.

##### Note
* Argo CD project errors. If you see a message like the one below in
  the output, rerun the above command again — see [#42][boot.argo-app-issue]
  about it.
  > unable to recognize "STDIN": no matches for kind "AppProject" in version "argoproj.io/v1alpha1"


#### Post-install steps

Run some smoke tests to make sure all the K8s resources got created,
all the services are up and running and there's no errors.

Notice Argo CD automatically generates an admin password on the first
deployment. To show it, run

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" | base64 -d && echo
```

You can use it if you get in trouble during the bootstrap procedure,
but keeping it around is like an accident waiting to happen. So you
should definitely zap it as soon as you've managed to log into Argo
CD with the password you entered in your own secret earlier. To do
that, just

```bash
$ kubectl -n argocd delete secret argocd-initial-admin-secret
```
Finally, if you like, you can set up remote access to the cluster through `kubectl`. One quick way to do that is to

1. Copy the content of `~/.kube/config` over to the box you want to
   access the cluster from.
2. Edit the file to change `server: https://127.0.0.1:16443` to the
   IP or host name of your freshly minted master node, e.g.
   `server: https://my-master-node:16443`.
3. Make it your current K8s config: `export KUBECONFIG=/where/you/saved/config`.

Or add an entry to your existing local K8s config if you have one.
Also, it's best to use the tools packed in our Nix shell on your
box too if you can. The procedure to install and use them is the
same as that detailed earlier for the cluster master node.

Now give yourself a pat on the shoulder. You've got a shiny, brand
new, fully functional KITT4SME cloud to...manage and maintain.
Godspeed!




[arch.cloud]: https://github.com/c0c0n3/kitt4sme/blob/master/arch/mesh/cloud.md
[argocd]: https://argoproj.github.io/cd/
[boot.argo-app-issue]: https://github.com/c0c0n3/kitt4sme.live/issues/42
[demo]: https://github.com/c0c0n3/kitt4sme/tree/master/poc
[istio]: https://istio.io/
[mk8s]: https://microk8s.io/
[mk8s.port-range]: https://github.com/ubuntu/microk8s/issues/284
[nix]: https://nixos.org/
[kitt4sme.live]: https://github.com/c0c0n3/kitt4sme.live
[sec]: ./security.md
