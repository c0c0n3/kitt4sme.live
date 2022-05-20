KITT4SME live platform
----------------------
> The AI's coming to the shop floor!

This repo contains a work-in-progress reference implementation of the
[KITT4SME platform][k4s].


### The what & the how

The what: **affordable, tailor-made AI at scale**

* Manufacturers on a budget and no IT expertise can still benefit
  from AI.
* AI developers can focus on delivering business value.
* The platform provider pools resources to slash IT costs.

The how: a **service mesh, multi-tenant, cloud architecture** to

* assemble AI components from a marketplace into a tailor-made
  service offering for a factory;
* connect them to the shop floor;
* enable them to store and exchange data in an interoperable,
  secure, privacy-preserving and scalable way.

![Platform tech stack in March 2022][dia.tech-stack]


### Docs

We have way less docs than we'd like to, but we'll keep on adding
stuff as we go along. Here's what's available at the moment.

* [Architecture][arch]. This is the repo where we keep most of the
  high-level tech docs, including a [catalogue][arch.catalogue] of
  the services the KITT4SME consortium are busy developing—the catalogue
  doesn't yet include the awesome software the open call winners will
  develop. Give those docs a read if you're trying to figure out how
  the whole thing hangs together :-)
* [Cluster bootstrap][boot]. Read this if you're itching to build
  your own KITT4SME cloud instance. If you're familiar with cloud
  computing and micro services architectures, you can probably whip
  it together in about 20 mins.
* [Security Ops][sec]. Managing cluster secrets, setting up SSO,
  and all that jazz.
* [Storage][storage]. How to manage cluster storage.
* [Deploying an app service][app-deployment]. How to package an app
  service for deployment, configure the KITT4SME platform instance
  and finally go live.
* [NGSI persistence][ngsi-p]. Short explanation of how KITT4SME
  automatically stashes away your NGSI data and builds time series
  out of it.


### Hacking

You're welcome to fork this repo and submit a PR :-) The `deployment`
directory contains the Kustomize code we use to build the platform
live at `kitt4sme.collab-cloud.eu` and keep it in sync with this repo.
The code is organised in sub-directories to mirror the layers detailed
in the [Cloud instance][arch.cloud] section of the architecture document.

If you want to develop your own platform app service, you could use
our [Roughnator][rtor] as a starting point. Roughnator is a REST service
that estimates surface roughness of manufacturing parts. The app receives
manufacturing part measurements from Orion (Context Broker), comes up
with a roughness forecast and then stashes that away into Orion. The
KITT4SME platform automatically builds time series of both input measurements
and output roughness estimates, making them available to other services.
The [Roughnator repo][rtor] also contains integration and end-to-end
tests to verify service functionality in a local Docker environment
that mimics the platform live environment where the service ultimately
gets deployed. Also, the GitHub repo is configured to run a CI/CD
pipeline that publishes Roughnator's Docker image on each software
release.


### Project management

We use a GitHub project to manage platform development. If you're
curious about what we've been up to and where we'll go next, head
over to [our project site][gh.proj] where you can find out about
objectives, roadmap and sprints. We've got lots of dev activities
going on in KITT4SME from design to coding to writing tech docs,
there's plenty to keep us busy. We put together a short intro on
how we use the GitHub project to keep tabs on dev activities and
get stuff done:

* [Hitchhiker's guide to the GitHub project][gh.proj-docs]




[app-deployment]: ./docs/how-to-deploy-app-svc.md
[arch]: https://github.com/c0c0n3/kitt4sme
[arch.catalogue]: https://github.com/c0c0n3/kitt4sme/blob/master/arch/catalogue/README.md
[arch.cloud]: https://github.com/c0c0n3/kitt4sme/blob/master/arch/mesh/cloud.md
[boot]: ./docs/bootstrap.md
[dia.tech-stack]: ./docs/tech-stack.svg
[gh.proj]: https://github.com/users/c0c0n3/projects/1
[gh.proj-docs]: https://github.com/c0c0n3/kitt4sme/blob/master/plan/hitchhiker/README.md
[k4s]: https://kitt4sme.eu/
[ngsi-p]: ./docs/ngsi-persistence.md
[rtor]: https://github.com/c0c0n3/kitt4sme.roughnator
[sec]: ./docs/security.md
[storage]: ./docs/storage.md
