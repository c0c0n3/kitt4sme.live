Deploying an app service
------------------------
> How to go live with an app service.

Let's have a look at how to deploy an application service to a live
KITT4SME platform instance. To make things more concrete, we'll use
one of KITT4SME's stock AI services, [Roughnator][roughnator]. It's
a REST service that estimates surface roughness of manufacturing parts.
The app receives manufacturing part measurements from Orion (Context
Broker), comes up with a roughness forecast and then stashes that
away into Orion. The KITT4SME platform automatically builds time series
of both input measurements and output roughness estimates, making
them available to other services. (So the AI app deployment doesn't
have to cater for that.)


### Packaging the service for deployment

The first step is to containerise the app and publish the container
image in a registry service. How you do this depends pretty much on
the app you've got so it's kinda pointless to talk about it here.
[Roughnator][roughnator] ships a Docker image that gets automatically
published in the GitHub Docker registry on each release build—check
out the GitHub actions in the repo for the details.

The next step is to whip together K8s deployment manifests. Here's
a simplified version of Roughnator's service descriptor which tells
K8s to create a cluster service called `roughnator` that'll accept
client requests on port `8000`. As we'll see later, this is where
Orion will send manufacturing part measurements received from the
shop floor.

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: roughnator
  name: roughnator
spec:
  ports:
  - name: http
    port: 8000
  selector:
    app: roughnator
```

And here's the corresponding deployment descriptor for the backing
pod.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: roughnator
spec:
  selector:
    matchLabels:
      app: roughnator
  template:
    spec:
      containers:
        - image: "ghcr.io/c0c0n3/kitt4sme.roughnator:latest"
          imagePullPolicy: IfNotPresent
          name: roughnator
          ports:
          - containerPort: 8000
            name: http
          env:
          - name: "ORION_BASE_URL"
            value: "http://orion:1026"
```

Like I said earlier, besides getting data from Orion, Roughnator also
saves roughness estimates to Orion. So it needs to know where to find
Orion in the cluster—that's the purpose of the `ORION_BASE_URL` env
var in the above YAML. Platform application services can access Orion
using a hostname of `orion` and a port of `1026`.


### Configuring the KITT4SME platform instance

Once you have the image and the K8s manifests, you've got to explain
to KITT4SME how to make your service go live in the cluster. We're
working on a Platform Configurator that should automate most (perhaps
all) of the steps below, so a service can be deployed by just pressing
a button in the RAMP marketplace. But until Platform Configurator is
ready, manual procedure it is. Don't stress, as you'll see it's not
a train smash.

KITT4SME adopts a DevOps approach to deployment. There's a GitHub
repo hosting all the code that makes up a live platform instance
and Argo CD monitors that repo to make sure that any change in the
repo gets reflected in the cluster. So the first thing to do is clone
the repo

```console
$ git clone https://github.com/c0c0n3/kitt4sme.live
```

Then make a directory to host your K8s manifests in the platform
application services deployment

```console
$ cd kitt4sme.live
$ mkdir deployment/plat-app-services/roughnator
```

combine your YAML manifests into a single `base.yaml` file and save
it in that directory. Also add a `kustomization.yaml` file with the
content below.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- base.yaml
```

KITT4SME uses Kustomize to process K8s manifests and the above YAML
simply tells Kustomize to include `base.yaml` in the deployment.
Likewise, you have to include the new directory in the deployment
too by adding the directory name to the list of resources in

* `deployment/plat-app-services/kustomization.yaml`

At this point you could already push the code to GitHub and watch
your service go live. But KITT4SME likes to manage deployments through
the Argo CD Web UI, so you should also create an Argo CD application
for your service. Here's how. Make a new directory for your service
in the Argo CD app services project as shown below.

```console
$ mkdir deployment/mesh-infra/argocd/projects/plat-app-services/roughnator
```

Then put an `app.yaml` file in it with the following content

```yaml
- op: replace
  path: /metadata/name
  value: roughnator
- op: replace
  path: /spec/source/path
  value: deployment/plat-app-services/roughnator
- op: replace
  path: /spec/project
  value: plat-app-services
```

The content is the same for all services, the only thing that changes
is the service and directory name, `roughnator` in this case. The other
required file in this directory is `kustomization.yaml` with instructions
to generate an Argo CD application manifest:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

patchesJson6902:
- target:
    kind: Application
    name: app
  path: app.yaml
```

Finally add the new directory name to the list of resources in

* `deployment/mesh-infra/argocd/projects/plat-app-services/kustomization.yaml`

I know, that's a ton of boilerplate, but like I said we're working on
automating all this. Anyhoo, we're ready to go live now.


### Go live

So how do we go live? Since Argo CD monitors the GitHub repo, all
we've got to do is push our changes to GitHub.

```console
$ git add .
$ git commit -m 'intial roughnator deployment.'
$ git push
```

Now if you log into the Argo CD Web UI, you should be able to see a
new "roughnator" application being deployed as in the screenshot down
below.

![Roughnator app in the Argo CD Web UI.][argocd.roughnator-app]


### Next steps

After the initial deployment, all the scaffolding is in place and
the next deployments should be a walk in the park. In fact, any change
you make to the YAML in the GitHub repo should be reflected in the
cluster within a couple of minutes. For example, say you wanted to
up the replica count to two. That's just an edit and commit away.
Edit the deployment descriptor

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: roughnator
spec:
  replicas: 2
  ...
```

and then push the change to GitHub. Shortly after that you should
see two pods tied to your deployment—if `kubectl` isn't your thing,
use the Argo CD Web UI to see what's happened to your deployment.

At this point Roughnator is just sitting there in the cluster without
actually having a chance to do anything useful. In fact, it needs to
get measurements from the shop floor to be able to output a forecast.
So how do we connect it to the shop floor? Well, through Orion. As
soon as a factory owner enables the Roughnator service in the RAMP
marketplace, an Orion subscription should be created for the platform
tenant representing the owner's company so that when their devices
start sending data over from the shop floor to the platform, that
data gets routed to Roughnator. At the moment, you've got to create
subscriptions manually through a script—have a look at Roughnator's
repo for an example. But hopefully going forward Platform Configurator
should be able to automate this bit too.




[argocd.roughnator-app]: ./argocd.roughnator-app.png
[roughnator]: https://github.com/c0c0n3/kitt4sme.roughnator
