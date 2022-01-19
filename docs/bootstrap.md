Cluster Bootstrap
-----------------
> One-off procedure to build & set up your KITT4SME mesh infra.

We're going to put together a single-node MicroK8s cluster to host
the KITT4SME platform. What we'll build is pretty much the same as
in the [Demo Cluster][demo], but we're swapping out Minikube for
[MicroK8s][mk8s] so we can still start small but then easily add
more nodes in the future.

We've got an Ubuntu VM at `kitt4sme.collab-cloud.eu` to host the
platform. (Ubuntu 20.04.1 LTS, GNU/Linux 5.4.0-42-generic x86_64,
8 CPUs, 16GB RAM/4GB swap, 120GB storage.) You can SSH into the box
with e.g.

```bash
$ ssh martel@kitt4sme.collab-cloud.eu
```

The instructions below tell you what to do to build the platform on
this box, but if you want to try this at home any Ubuntu box with the
same specs will do. If you have Multipass, you can spin up a 20.4
Ubuntu VM

```bash
$ multipass launch --name kitt4sme --cpus 2 --mem 4G --disk 40G 20.04
$ multipass shell kitt4sme
```

and then follow the instructions below. Keep in mind, depending on
what you'll do with your toy platform later, you might need more RAM
and storage.


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

NOTE. Always install the latest Nix. At the moment the latest version
is `2.4`. You might install a newer version when you read this, but
that's fine too.

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
$ echo 'nix develop github:c0c0n3/kitt4sme.live?dir=nix' > ~/tools.sh
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

Deploy Istio to the cluster using our demo profile

```bash
$ wget -q -O profile.yaml https://raw.githubusercontent.com/c0c0n3/kitt4sme.live/main/deployment/mesh-infra/routing/istio-demo-profile.yaml
$ istioctl install -y --verify -f profile.yaml
```

Platform infra services (e.g. FIWARE) as well as app services (e.g.
AI) will sit in K8s' `default` namespace, so tell Istio to auto-magically
add an Envoy sidecar to each service deployed to that namespace

```bash
$ kubectl label namespace default istio-injection=enabled
```

Have a read through the [Demo Cluster][demo] section on installing
Istio for more info about our Istio setup with add-ons.


### Continuous delivery

[Argo CD][argocd] will be our declarative continuous delivery engine.
(Read the [Cloud instance][arch.cloud] section of the architecture
document about our IaC approach to service delivery.) Except for the
things listed in this bootstrap procedure, we declare the cluster
state with YAML files that we keep in the `deployment` dir within
[our GitHub repo][kitt4sme.live]. Argo CD takes care of reconciling
the current cluster state with what we declared in the repo.

For that to happen, we've got to deploy Argo CD and tell it to use
the YAML in our repo to populate the cluster. Our repo also contains
the instructions for Argo CD to manage its own deployment state as
well as the rest of the KITT4SME platform — I know, it sounds like
a dog chasing its own tail, but it works. So we can just build the
YAML to deploy Argo CD and connect it to our repo like this

```bash
$ kustomize build \
    https://github.com/c0c0n3/kitt4sme.live/deployment/mesh-infra/argocd | \
    kubectl apply -f -
```

##### Note
Argo CD project errors. If you see a message like the one below in
the output, rerun the command again — see [#42][boot.argo-app-issue]
about it.

> unable to recognize "STDIN": no matches for kind "AppProject" in version "argoproj.io/v1alpha1"


After deploying itself to the cluster, Argo CD will populate it with
all the K8s resources we declared in our repo and so slowly the KITT4SME
platform instance will come into its own. This will take some time.
Go for coffee. Then run some smoke tests to make sure all the K8s
resources got created, all the services are up and running and there's
no errors.

One last thing. The Argo CD YAML in our repo sets the admin password
too — username: `admin`. If you can't remember what the heck was that
password, you'll have to regenerate it, put it in the YAML and wait
for Argo CD to sync again. If you're in a hurry, you can force Argo
CD to sync right away. Uh, how you ask if I don't have a password?
Well, there's a bootstrap backdoor: Argo CD automatically generates
an admin password on the first deployment. To show it, run

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" | base64 -d && echo
```

Keeping that initial admin password around is like an accident waiting
to happen. So you should definitely zap the K8s secret as soon as you
can with

```bash
$ kubectl -n argocd delete secret argocd-initial-admin-secret
```


### Post-install steps

After running some smoke tests to make sure all the services and
other bits and pieces are in place, you've got to create an initial
KITT4SME platform admin user. That's the Keycloak admin user for the
master realm. To do that, you need to connect to the platform from
your machine using a Web browser and then enter the admin username
and password as explained in the [Keycloak manual][keycloak.fst-admin].
Here's how.

1. Copy the content of `~/.kube/config` on `kitt4sme.collab-cloud.eu`
   over to your box.
2. Edit the file to change `server: https://127.0.0.1:8081` to
   `server: https://kitt4sme.collab-cloud.eu:8081`.
3. Make it your current K8s config: `export KUBECONFIG=/where/you/saved/config`.
4. Tunnel your local port `8080` to that of the Keycloak service in
   the cluster: `kubectl port-forward svc/keycloak 8080:8080`
5. Open `http://localhost:8080` in your browser.
6. You should see the Keycloak new admin form. Enter a username and
   a **very strong** password.
7. Stop port-forwarding, delete the K8s admin config you copied over
   earlier and exit the shell—which zaps `KUBECONFIG` you set earlier.

##### Note
Why not create the Keycloak admin right on `kitt4sme.collab-cloud.eu`?
See [#70][boot.fst-admin-issue] about it.


Now give yourself a pat on the shoulder. You've got a shiny, brand
new, fully functional KITT4SME cloud to...manage and maintain.
Godspeed!




[arch.cloud]: https://github.com/c0c0n3/kitt4sme/blob/master/arch/mesh/cloud.md
[argocd]: https://argoproj.github.io/cd/
[boot.argo-app-issue]: https://github.com/c0c0n3/kitt4sme.live/issues/42
[boot.fst-admin-issue]: https://github.com/c0c0n3/kitt4sme.live/issues/70
[demo]: https://github.com/c0c0n3/kitt4sme/tree/master/poc
[istio]: https://istio.io/
[keycloak.fst-admin]: https://www.keycloak.org/docs/latest/server_admin/#creating-first-admin_server_administration_guide
[mk8s]: https://microk8s.io/
[mk8s.port-range]: https://github.com/ubuntu/microk8s/issues/284
[nix]: https://nixos.org/
[kitt4sme.live]: https://github.com/c0c0n3/kitt4sme.live
