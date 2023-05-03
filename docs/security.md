Security
--------
> Keeping the meanies out.


### Managing secrets

We set up our GitOps pipeline so

1. Secrets can be safely kept in our GitHub public repo.
2. When we push a secret update to the repo, the cluster processes
   that use the secret get to see the new secret data as soon as
   possible and without any manual intervention.

In fact, we use [Sealed Secrets][sealsec] and [Reloader][reloader]
to achieve (1) and (2). Sealed Secrets lets us encrypt plain K8s
`Secret`s and store them in our repo. We use the `kubeseal` tool
to convert a plain K8s `Secret` into a `SealedSecret` CRD containing
the original secret data but encrypted. We keep `SealedSecret`s in
our repo, but never the original `Secret`s used to generate them.
When Argo CD deploys a `SealedSecret`, the Sealed Secrets controller
in the live cluster decrypts the data back into a plain K8s `Secret`.
Reloader monitors the deployment so as soon as the controller creates
or updates a `Secret` object, Reloader bounces the pods referencing
it.

Why not use plain Kustomize instead of Reloader? We actually tried a
Sealed Secrets + Kustomize only setup and developed a test bed for it.
You can find the [code and docs here][seal-sec-w-kust] along with an
explanation of why we think this setup isn't optimal.

#### Storing secrets in the repo
We keep all `Secret`-related stuff in

* `deployment/mesh-infra/security/secrets`

The `templates` sub-directory contains plain K8s `Secret` manifests
we use to generate the actual `SealedSecret` to be deployed to the
cluster. If you're creating a new `Secret`, you should add a template
for it, so the next dev after you will have an easy time updating the
secret.

A template file is basically just a K8s `Secret` manifest with dummy
values in the secret data fields. But you've got to remember to add
a Sealed Secrets annotation like this

```yaml
# ...
  annotations:
    sealedsecrets.bitnami.com/managed: "true"
# ...
```

The annotation tells Sealed Secrets Controller to update an existing
`Secret` object in the cluster whenever the corresponding `SealedSecret`
changes. When we update a `SealedSecret`, Controller will extract its
secret data, but if another `Secret` with the same name exists, Controller
will refuse to update it with the new content just unsealed unless
the `Secret` object has the above annotation attached to it.

We keep the `SealedSecret`s generated out of the templates in the
`secrets` directory, using the same file name as the template. The
file name should follow this pattern: `<secret name>.yaml`. E.g.
keep a `Secret` named `keycloak-builtin-admin` in a file named
`keycloak-builtin-admin.yaml`.

#### Workflow
The first step to create a new `Secret` or update an existing one is
to clone the repo. After cloning, get into the KITT4SME Nix shell,
then go to the `secrets` directory

```console
$ cd nix
$ nix shell
$ cd ../deployment/mesh-infra/security/secrets
```

Now edit an existing template (or create a new one) to enter the
secret data in plain text. Then generate the `SealedSecret` by
running `kubeseal` as in the example below.

```console
$ kubeseal -o yaml < templates/keycloak-builtin-admin.yaml > keycloak-builtin-admin.yaml
```

Notice `kubeseal` needs to be able to access the cluster for that to
work. You can also work offline if you like, but you'll have to fetch
the controller pub key with `kubeseal --fetch-cert` beforehand. Read
the Sealed Secrets docs for the details.

As soon as you've generated the `SealedSecret`, you should use `git`
to revert the changes you made to the template to avoid committing
actual plain text secret data.

Finally, make sure each `Deployment` referencing the `Secret` has
a Reloader annotation to track secret updates. Set the secret name
as annotation value like in the example below.

```yaml
# ...
metadata:
  annotations:
    secret.reloader.stakater.com/reload: "keycloak-builtin-admin"
# ...
```

Commit your changes and push upstream. Done!

#### Docker image secrets
We basically use the same approach as above for managing Docker image
secrets K8s can use to pull images from private registries. For an
example of that, have a look at [PR #161][pr161] where we use a simple
[script][pr161.script] to generate the Docker secret and stash it away
in a [Sealed Secret][pr161.secret] which then gets used in the service
[deployment][pr161.deploy].


### Argo CD SSO

You can configure Argo CD with Keycloak single-sign on. To do that,
you've got to create an Argo CD OIDC client, scopes and group in the
KITT4SME Keycloak service, then tweak the Argo CD config in the mesh
infra. The procedure is pretty much the same as that explained in the
[Argo CD manual][argocd.keycloak-sso]. Short version below.

#### Keycloak realm
Log into the `master` realm with your Keycloak `admin` user. We'll
set up Argo CD SSO in the `master` realm since Argo CD is part of the
KITT4SME mesh infra which only platform admins should have access to.

#### Keycloak group
Create a user group called `ArgoCDAdmins`, then add your Keycloak
`admin` user to this group.

#### Keycloak client scopes
Create a client scope for the Argo CD OIDC client.

- **Name**: groups
- **Mappper**
  - **Name**: groups
  - **Mapper Type**: Group Membership
  - **Token Claim Name**: groups
  - **Full group path**: off

#### Keycloak OIDC client
Add a new OIDC client.

- **Client ID**: argocd
- **Root URL**: https://kitt4sme.collab-cloud.eu/argocd (if you're
  building your own cluster replace the host part of the URL with yours,
  but keep the `/argocd` path)
- **Access Type**: `confidential`
- **Valid Redirect URIs**: https://kitt4sme.collab-cloud.eu/argocd/auth/callback
  (if you're building your own cluster replace the host part of the
  URL with yours, but keep the `/argocd/auth/callback` path)
- **Base URL**: /applications
- **Client Scopes**: add `groups` to **Default Client Scopes**

Copy out the secret (*Credentials* tab) and encode it in Base-64

```console
$ echo -n 'KsqP0p5TevBPtiHLMXUJBCiubGutgpib' | base64
S3NxUDBwNVRldkJQdGlITE1YVUpCQ2l1Ykd1dGdwaWI=
```

#### Argo CD config
The `deployment/mesh-infra` directory already contains the files you'll
need for the SSO setup, pre-configured to match the values you entered
earlier in Keycloak.

- `argocd/argocd-cm.yaml`: Keycloak `master` realm URL, Argo CD root URL,
  OIDC client ID of `argocd` and `groups` client scope. At the moment this
  file also contains the `kitt4sme.collab-cloud.eu` TLS cert because the
  certificate authority that signed it is not among those Argo CD trusts.
- `argocd/argocd-rbac-cm.yaml`: Argo CD admin permissions to any member of
   the Keycloak `ArgoCDAdmins` group.
- `security/secrets/argocd.yaml`: sealed secret containing the Argo CD
   client secret from Keycloak.

So all you need to do is regenerate the Argo CD sealed secret with the
Keycloak Argo CD client secret you Base-64 encoded earlier:

```yaml
# security/secrets/templates/argocd.yaml
# ...
  oidc.keycloak.clientSecret: S3NxUDBwNVRldkJQdGlITE1YVUpCQ2l1Ykd1dGdwaWI=
# ...
```

Then

```console
$ cd security/secrets
$ kubeseal -o yaml < templates/argocd.yaml > argocd.yaml
```

and push upstream as explained in the "Managing secrets" section.




[argocd.keycloak-sso]: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/keycloak/
[pr161]: https://github.com/c0c0n3/kitt4sme.live/pull/161
[pr161.deploy]: https://github.com/c0c0n3/kitt4sme.live/pull/161/files#diff-447dd6978db4b68bc6c30273982a81f658ed8293aade4f641ad7a20470cab36c
[pr161.secret]: https://github.com/c0c0n3/kitt4sme.live/pull/161/files#diff-f36d24b0ef2a4c7a800aeb9230533d756a3796299a5f6e9d5754f2ca068a418d
[pr161.script]: https://github.com/c0c0n3/kitt4sme.live/pull/161/files#diff-3613c00bf3d8759a8e2cce9f1f7cd878db383f159429790dcfd7a868b736b1eb
[reloader]: https://github.com/stakater/Reloader
[sealsec]: https://github.com/bitnami-labs/sealed-secrets
[seal-sec-w-kust]: ../dev/sealed-sec-w-kustomize
