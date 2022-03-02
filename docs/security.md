Security
--------
> Keeping the meanies out.


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
- **Root URL**: https://kitt4sme.collab-cloud.eu/argocd
- **Access Type**: `confidential`
- **Valid Redirect URIs**: https://kitt4sme.collab-cloud.eu/argocd/auth/callback
- **Base URL**: /applications
- **Client Scopes**: add `groups` to **Default Client Scopes**

Copy out the secret (*Credentials* tab) and encode it in Base-64

```console
$ echo -n 'KsqP0p5TevBPtiHLMXUJBCiubGutgpib' | base64
S3NxUDBwNVRldkJQdGlITE1YVUpCQ2l1Ykd1dGdwaWI=
```

#### Argo CD config
The `deployment/mesh-infra/argocd` directory already contains the
files you'll need for the SSO setup, pre-configured to match the
values you entered earlier in Keycloak.

- `argocd-cm.yaml`: Keycloak `master` realm URL, Argo CD root URL,
  OIDC client ID of `argocd` and `groups` client scope.
- `argocd-rbac-cm.yaml`: Argo CD admin permissions to any member of
   the Keycloak `ArgoCDAdmins` group.
- `argocd-secret.yaml`: Base64-encoded secret of the Argo CD client
  in Keycloak.

So all you need to do is to set the Keycloak Argo CD client secret
you Base-64 encoded earlier:

```yaml
# argocd-secret.yaml
# ...
  oidc.keycloak.clientSecret: S3NxUDBwNVRldkJQdGlITE1YVUpCQ2l1Ykd1dGdwaWI=
# ...
```




[argocd.keycloak-sso]: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/keycloak/
