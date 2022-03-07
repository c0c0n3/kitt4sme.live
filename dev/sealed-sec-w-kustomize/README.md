SealedSecrets with Kustomize
----------------------------
> A popular approach to secret updates you should probably avoid...

We'd like to set up our GitOps pipeline so

1. Secrets can be safely kept in our GitHub public repo.
2. When we push a secret update to the repo, the cluster processes
   that use the secret get to see the new secret data as soon as
   possible and without any manual intervention.

A popular approach is to use Bitnami's [Sealed Secrets][sealsec] along
with a [Kustomize hack][sealsec-w-kust] to get the job done. We're
going to explore a similar setup down below and then talk about why
this may not be such a good idea.

To follow along, you'll need a running KITT4SME cluster and admin
access to it through `kubectl`. Then clone `kitt4sme.live` and

```console
$ cd nix
$ nix shell
$ cd ../dev/sealed-sec-w-kustomize
```

Before you venture in the mess below, keep in mind we wrote this with
an experienced K8s system admin in mind. If K8s and Kustomize aren't
your cup of tea, it's going to be pretty hard to make sense of the
mumbo jumbo below.


### Sealed Secrets and K8s Secret updates

As we all know, K8s `Secrets` aren't really "secret". The data they
contain is just the original plain text encoded in Base64. So while
it's fine for an admin to manually deploy them to the cluster, they
are a bit of a challenge when it comes to a fully automated GitOps
workflow where all the K8s manifests should be in your repo—single
source of truth, audit trails, and all that jazz, you know the drill.

[Sealed Secrets][sealsec] let's you safely keep your secrets in an
online repo, even if it's public. Uh? Yah, the way it works is that
you don't actually commit the original secret data to the repo but
an encrypted version of it. In fact, you use the `kubeseal` tool to
generate a `SealedSecret` CRD out of an input K8s `Secret` and then
commit the `SealedSecret` to the repo, not the `Secret`. When your
GitOps pipeline deploys the `SealedSecret` to the cluster, Sealed
Secrets Controller (which you install as part of the setup) decrypts
the data you encrypted earlier to create the actual `Secret` for you
in the cluster.

That's a nice way to tackle (1) but what about (2)? When will the
`Secret` Sealed Secrets Controller unpacks become visible to the
running processes that reference it—e.g. through a `Deployment`?
Well, if you mounted the `Secret` through a volume, then K8s will
push the updated `Secret` data to the pod during the next Kubelet
sync cycle–typically about a minute later with default K8s settings.
But if the `Secret` values got read through environment variables,
you'd be out of luck since K8s can't update those and you'll have
to manually bounce the pod or deployment. And unless you know the
process monitors the file system, you should probably restart it
even if the `Secret` is mounted on a volume.


### Test bed

We've put together a little test bed to experiment with the stuff
we're talking about here. Here's how it works.

* Plain secret. A `Secret` named `admin-password` with a `password`
  data field in it. This is the input `Secret` to pass to `kubeseal`.
  File: `plain-secret.yaml`.
* Sealed secret. A `SealedSecret` `kubeseal` generates from the plain
  secret with the same name but encrypted `password` field. We save
  it to the `sealed-secret.yaml` file.
* Secret reader. A simple Bash loop to read the `Secret` Sealed
  Secrets Controller extracts from the `SealedSecret`. It's deployed
  in a Busy Box pod and configured with an environment variable sourcing
  the `password` field value straight from the `admin-password` `Secret`
  as well as volume mount with the `admin-password` content. The loop
  reads both the environment variable and the file content every 30
  seconds and then prints these values to `stdout`.
  File: `deployment.yaml`.
* Kustomize. We've also got some Kustomize scripts to deploy the
  reader and the generated `SealedSecrets` CRD.
  Files: `kustomization.yaml`, `name-refs.yaml`.

To get our feet wet, let's see for ourselves how K8s updates the
`Secret` data in the volume but not the environment variable. Start
off by commenting out the `configurations`,`generatorOptions` and
`secretGenerator` stanzas in `kustomization.yaml`. Then generate
the `SealedSecret`, deploy to the cluster and check out what the Bash
loop gets to see.

```console
$ kubeseal -o yaml < plain-secret.yaml > sealed-secret.yaml
$ kustomize build . | kubectl apply -f -
$ kubectl logs -f deployment/busybox
16:51:10 | env: yo! | file: yo!
16:51:40 | env: yo! | file: yo!
```

The printed value of the environment variable and file content should
be the same as the value of the `password` field in the plain secret.
Here's what happened under the bonnet:

1. K8s created the `SealedSecrets` CRD. It also created a `Deployment`
   and `Pod` for Secret Reader, pulled the `password` value into the
   environment variable and mounted the `Secret` on the pod's file
   system.
2. Sealed Secrets Controller decrypted the `SealedSecret` and created
   a `Secret` with the same name of `admin-password` and the `password`
   value in it.
3. Secret Reader printed the `password` values it found in the environment
   and in the file.

Now for the fun part. Edit `plain-secret.yaml` to change the password
value to e.g. "wazzup". Then regenerate the `SealedSecret` and deploy
again. Secret Reader should be able to pick up the new value from the
file, but the environment variable will be stuck forever with the old.

```console
$ kubectl logs -f deployment/busybox
16:51:10 | env: yo! | file: yo!
16:51:40 | env: yo! | file: yo!
16:52:10 | env: yo! | file: yo!
16:52:40 | env: yo! | file: wazzup
16:53:10 | env: yo! | file: wazzup
16:53:40 | env: yo! | file: wazzup
```

Clean up after yourself

```console
$ kustomize build . | kubectl delete -f -
```


### Making Kustomize use unique sealed names

What can you do to propagate `Secret` updates to the processes running
in the cluster that use those secrets? One community-blessed approach
is to make `Secret`s immutable, i.e. new data also means new secret
name, and then update the K8s objects that reference them with the
new name. Because the referred name has changed, K8s is forced to
update `Deployment`, `Pod` and friends which ultimately results in
the processes being restarted with the new secret values.

Kustomize can help here with its secret generator feature. In fact,
if you declare your secret in a `secretGenerator` stanza, when you
run the `build` command, Kustomize will automatically append a hash
of the `Secret`'s content to the `Secret`'s name and update all manifests
referencing that secret accordingly. So when you `apply` the Kustomize
generated manifests to the cluster, K8s will eventually bounce all
the processes that use those secrets.

If only Kustomize worked the same for `SealedSecret`s. But it can't
since it don't know two flippin' flies about `SealedSecret`. Surely
we could write a plugin, but there's also a hack we can plonk down.
Here's the idea.

* Tie `Secret` names to `SealedSecret` names. Tell Kustomize that if,
  when running the `build` command, it sees an input `Secret` called
  `x` and a `SealedSecret` also called `x`, then if it needs to rename
  `Secret x` to `y` in the output, it should do the same with the
  associated sealed secret—i.e. also rename `SealedSecret x` to `y`.
  Have a look at the Kustomize config in `name-refs.yaml`.
* Pair a dummy Kustomize-managed `Secret` with each `SealedSecret`.
  If you have a `SealedSecret` called `x`, also add a secret called
  `x` to the `secretGenerator` stanza. Tell Kustomize to read the
  dummy secret's data from the file containing the `SealedSecret`.
  The implementation is in `kustomization.yaml`.

With this setup, when Kustomize builds the output manifests, it'll
output a unique name for each dummy `Secret x` by appending the hash
`h` of the referenced `SealedSecret x` file. So `Secret x` gets renamed
to `x-h`. But now Kustomize is forced to update all name references
to the original `Secret x` to `x-h`, including those in `SealedSecret x`.
If later on you regenerate `SealedSecret x`, the content will be different
so Kustomize will compute a different hash too.

To see how this works in practice, generate a secret with a password
of "yo!". Edit `plain-secret.yaml` to enter "yo!" in the `password`
field. Then generate the `SealedSecret` with `kubeseal` and check
Kustomize appends the same hash to each `admin-password` name.

```console
$ kubeseal -o yaml < plain-secret.yaml > sealed-secret.yaml
$ kustomize build . | grep 'admin-password'
  name: admin-password-mkh5t5mfcm
              name: admin-password-mkh5t5mfcm
          secretName: admin-password-mkh5t5mfcm
  name: admin-password-mkh5t5mfcm
      name: admin-password-mkh5t5mfcm
```

Now change the password to "wazzup" and regenerate the sealed secret.
The hash should be different.

```console
$ kubeseal -o yaml < plain-secret.yaml > sealed-secret.yaml
$ kustomize build . | grep 'admin-password'
  name: admin-password-m6f5dcfct5
              name: admin-password-m6f5dcfct5
          secretName: admin-password-m6f5dcfct5
  name: admin-password-m6f5dcfct5
      name: admin-password-m6f5dcfct5
```


### Putting the Kustomize hack to good use

Can we profit from the above hack? Sure thing.

```console
$ kustomize build . | kubectl apply -f -
$ kubectl logs -f deployment/busybox
17:29:10 | env: wazzup | file: wazzup
17:29:40 | env: wazzup | file: wazzup
```

But, what happened under the bonnet?

1. K8s created the `SealedSecrets` CRD `admin-password-m6f5dcfct5`
   containing the encrypted secret and a dummy `Secret` also named
   `admin-password-m6f5dcfct5`.
2. Sealed Secrets Controller decrypted the `SealedSecret` and overrode
   the existing dummy `Secret` with the content of the decryted secret,
   i.e. the password originally in `plain-secret.yaml`. This is because
   the `SealedSecret`, encrypted secret and dummy secret all have the
   same name of `admin-password-m6f5dcfct5`.
3. K8s created a `Deployment` and `Pod` for Secret Reader, pulled
   the `password` value into the environment variable and mounted
   `Secret admin-password-m6f5dcfct5` on the pod's file system.
4. Secret Reader printed the `password` values it found in the environment
   and in the file.

Should we try updating the password? Edit `plain-secret.yaml` to
change the password value back to "yo!", regenerate the sealed secret
and deploy again.

```console
$ kubeseal -o yaml < plain-secret.yaml > sealed-secret.yaml
kustomize build . | kubectl apply -f -
$ kubectl logs -f deployment/busybox
17:32:10 | env: yo! | file: yo!
17:32:40 | env: yo! | file: yo!
```

As you can see the new password value became available both in the
file and the environment variable. Sweet. How did it happen?

1. K8s created the `SealedSecrets` CRD `admin-password-mkh5t5mfcm`
   containing the encrypted secret and a dummy `Secret` also named
   `admin-password-mkh5t5mfcm`. Recall in the previous run the name
   was different, `admin-password-m6f5dcfct5`, which is why K8s
   created new objects.
2. Sealed Secrets Controller decrypted the `SealedSecret` and overrode
   the existing dummy `Secret` with the content of the decryted secret,
   i.e. the password originally in `plain-secret.yaml`. This is because
   the `SealedSecret`, encrypted secret and dummy secret all have the
   same name of `admin-password-mkh5t5mfcm`.
3. K8s updated the existing Secret Reader `Deployment` because the
   name of the referenced secret changed from `admin-password-m6f5dcfct5`
   to `admin-password-mkh5t5mfcm`. The `Pod` got restarted so Secret
   Reader picked up the new password values both from the environment
   and from the file.
4. Secret Reader printed the new `password` value of "yo!" it found
   in the environment and in the file.


### GitOps workflow

So where does all this leave us? Well, thanks to Sealed Secrets, we
can manage secrets through our GitOps workflow simply by keeping sealed
secrets in our repo instead of plain K8s secrets. From a developer's
standpoint, the workflow would be

1. Generate a `SealedSecret` manifest from a plain K8s `Secret`.
2. Add a dummy secret to Kustomize's `secretGenerator` stanza. The
   dummy secret name must be the same as that of the `SealedSecret`
   and input `Secret`. Also, the dummy secret must import its content
   from the `SealedSecret` manifest file.
3. List the `SealedSecret` manifest in Kustomize's `resources` stanza.
4. Push the change set to the repo.

After that, Argo CD will pick up the new change set from the repo,
run Kustomize to generate up-to-date K8s manifests and finally apply
those manifests to the live cluster. Any process referencing the secret
should eventually get restarted automatically so it should eventually
see the new secret data—at least that's the hope, read more about it
in the next section.


### Party poopers

Happy days, mission accomplished! Not quite actually. Like I said,
with this approach we can definitely achieve objective (1)—safely
keep secrets in a public repo. As for (2), automatic secret updates,
I'm not convinced yet. Even though in my tests I haven't managed to
break it yet, it seems to me this hack works more by accident than
by design.

In principle, there are race conditions that could lead to processes
not seeing the updated secret. At least two such conditions spring
to mind

* K8s writes the dummy secret after Sealed Secrets Controller
  extracted the actual one.
* K8s updates the deployment and pods before Sealed Secrets
  Controller extracts the actual secret.

In both cases, the processes would get to see the dummy secret and
possibly crash or just discard the data, so they might not see the
actual secret until an operator fixes up the cluster configuration.

Also for the record, over time `SealedSecret` junk will pile up in
the cluster. In fact, every time you deploy the CRD name will be
different because of the hash appended to the base name. So every
now and then you should manually clean up

```console
$ kubectl delete sealedsecret --all
```

This will clean up the linked `Secret` objects too since those are
"owned" by their `SealedSecret`s. After spring cleaning, you've got
to redeploy everything though, since all your secrets are gone!




[sealsec]: https://github.com/bitnami-labs/sealed-secrets
[sealsec-w-kust]: https://faun.pub/sealing-secrets-with-kustomize-51d1b79105d8
