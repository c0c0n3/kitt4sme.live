Cluster Bootstrap
-----------------
> One-off procedure to build & set up your KITT4SME mesh infra.

We're going to put together a single-node MicroK8s cluster to host
the KITT4SME platform that you, as an open call developer, will use
to integrate your solution. We use [MicroK8s][mk8s] so we can start
small but then easily add more nodes in the future if needed.

You need to provision some hardware to run the KITT4SME platform.
Like I said earlier, we'll start with just one node, but feel free
to expand the cluster later if you need to. Anyway, the initial node
should have at least 8 CPUs, 16GB RAM/4GB swap, 120GB storage. Once
you've got that box, you'll have to install Ubuntu 20.04.1 LTS
(GNU/Linux 5.4.0-42-generic x86_64) on it. Please install the exact
version mentioned here.

#### Tip
If you just want to try out the platform quickly, you can spin up an
Ubuntu 20.04 VM in no time with Multipass, e.g.

```bash
$ multipass launch --name kitt4sme --cpus 2 --mem 4G --disk 40G 20.04
$ multipass shell kitt4sme
```

and then follow the instructions below. Keep in mind, depending on
what you'll do with your toy platform later, you might need more RAM
and storage.


### Preparing your own fork

The first step is to fork `kitt4sme.live` on GitHub so you can use
your fork as a GitOps source for building your cluster. Then in your
fork edit

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

Notice the `targetRevision` field specifies which branch to use in
your repo. Keep `open-calls` for the bootstrap procedure and change
it later if you'd like to use a different branch instead.

When done, commit your changes and push upstream to your fork.


### Tools

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


### Cluster orchestration

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


### Mesh infra

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


### Continuous delivery

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


### Post-install steps

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

Finally, if you like, you can set up remote access to the cluster
through `kubectl`. One quick way to do that is to

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
