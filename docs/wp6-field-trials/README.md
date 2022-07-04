WP6 Field Trials
----------------
> Hitting the ground running!

This section outlines how the KITT4SME platform has been packaged
and made available for the pilot deployments to be carried out in
WP6. We begin with a brief review of the automated service delivery
capabilities of the platform and how to instantiate a KITT4SME cloud.
Follows a report of how the platform has been instantiated for the
WP6 pilot deployments along with some deployment considerations and
possible further customisations available to each industry partner
involved in the field trials.


### Automated service delivery

The KITT4SME platform features automated service delivery through
GitOps. The platform provider's staff describe the state of a KITT4SME
platform deployment through version-controlled text files hosted in
an online Git repository. Each file declares a desired instantiation
and runtime configuration for some of the services in a specified
KITT4SME cluster. Collectively, the files at a given Git revision
describe the deployment state of these services at a certain point
in time. The KITT4SME platform ships with GitOps software (Argo CD)
that monitors the Git repository in order to automatically reconcile
the desired deployment state with the actual live state of the KITT4SME
cluster.


### Platform instantiation

A KITT4SME [platform instance][arch.cloud] comprises several process
layers and hardware on which these processes run:

* Hardware layer. The cluster hardware—computers, network, storage.
* Cluster orchestration. Kubernetes processes that manage the computational
  resources (CPU, memory, storage) provided by the hardware layer and
  allocate them to processes in the other layers. Argo CD also belongs
  in this layer, orchestrating the deployment and configuration of
  services from the KITT4SME Git repository.
* Control plane. Istio processes that manage a network of proxies to
  transparently route and balance service traffic, secure communication
  and access to service resources, and monitor service operation.
* Data plane. Istio proxies along with the interconnection network
  required to capture and process application traffic destined for
  or originating from services.
* Platform infrastructure services. Processes that support the operation
  of application services, among which, the FIWARE middleware and database
  processes mentioned earlier.
* Platform application services. The services that are an integral
  part of the KITT4SME workflow and described earlier in this document.

(The cluster orchestration, control and data plane collectively make
up the "mesh infrastructure", as specified in the KITT4SME [platform
architecture][arch.cloud].)

As noted earlier, text files (such as Kubernetes descriptors, Istio
routing rules, OPA policies, etc.) describe how these layers are to
be instantiated, configured and run on the target cluster hardware.
Given a Git repository containing these files, Argo CD orchestrates
the instantiation of the KITT4SME platform layers in the target cluster.
The attentive reader will have noticed the chicken-and-egg problem
here: Argo CD automatically realises the runtime configuration declared
in the Git repository (including its own!) but how does Argo CD come
into being in the first place?

The solution to this conundrum is that indeed there is a one-off
procedure to bootstrap a platform instance. This procedure is quite
simple and takes about twenty minutes to perform:

* Hardware. A single node (either physical server or virtual machine)
  needs to be provisioned along with storage and network. Additional
  nodes can be added later as needed, after the bootstrap procedure.
* Microk8s. A basic installation of this Kubernetes distribution is
  required.
* Istio. A pre-configured, minimal installation of Istio must be carried
  out too. This package is available in the official KITT4SME repository.
* Argo CD. As for Istio, the KITT4SME repository contains a package
  to deploy a minimal Argo CD service. The operator must connect the
  Git repository to the Argo CD service when performing this initial
  deployment.

As soon as Argo CD is operational, it deploys the rest of the platform
as per instructions found in the Git repository. This includes both
the platform application and infrastructure services as well as completing
the mesh infrastructure deployment—which also includes Argo CD itself!
From this point on, Argo CD will keep in synch the Git repository with
the actual cluster state so that any changes made to the Git repository
are eventually realised in the live platform instance.

Please note that a detailed, step-by-step, technical reference about
the bootstrap procedure just outlined is [available online][bootstrap].


### Pilot deployments

WP6 will carry out four pilot deployments to evaluate the KITT4SME
platform in the context of the manufacturing processes selected by
the KITT4SME consortium's industry partners. Each field trial will
involve one industry partner and a KITT4SME service kit specifically
designed and assembled for that partner's use case as summarised below:

* Injection moulding (Task 6.2). In this deployment Fatigue monitoring
  system, Intervention Manager and Sensing Layer will orchestrate
  robots and operators in Ghepi's injection moulding process to reduce
  operator stress levels and fatigue as well as increasing overall
  productivity.
* Fastener sorting (Task 6.3). AI for Quality Systems will enhance
  Dimac's capability to detect faulty parts early in the manufacturing
  process.
* Hand tools (Task 6.4). Vision for Quality Excellence and Shop Floor
  Anomaly Detection System will provide an almost entirely automated
  solution to Ideal Tek’s problem of assessing whether product features,
  such as dimensions, conform to specifications.
* Electrical equipment (Task 6.5). Shop Floor Anomaly Detection System
  and Intervention Manager will help Wamtechnik’s engineers to optimise
  battery production thanks to real-time quality assessment and reconfiguration
  recommendations.

(Details about the above applications can be found in the [online
catalogue][arch.catalogue].)

WP2, WP3 and WP4 have developed the software that will be used for
the above field trials. All the relevant software has been assembled
and configured in the KITT4SME platform instance to be used by WP6.
This instance has been bootstrapped (as explained earlier) and is
currently live at:

* http://kitt4sme.collab-cloud.eu/

The Git repository hosting the files declaring this live instance
and from which the cluster is built is publicly available at:

* https://github.com/c0c0n3/kitt4sme.live

The live platform for pilot deployments comprises 

* Hardware. Virtual machines, storage and network provided by VTT
  and located in their data centre in Finland.
* Mesh infrastructure. MicroK8s, Istio, Istio extensions (Grafana,
  Jaeger, Kiali, Prometheus), Argo CD, routing, Keycloak, OPA, Rego
  policies, secrets, Kubeseal, Reloader, virtual storage.
* Platform infrastructure services. Orion LD, Agents, QuantumLeap,
  MongoDB, CrateDB, Postgres, Timescale, MQTT.
* Platform application services. Fatigue Monitoring System, Intervention
  Manager, Sensing Layer, AI for Quality Systems, Vision for Quality
  Excellence, Shop Floor Anomaly Detection System. 


### Additional considerations

The KITT4SME [kitt4sme.live repository][k4s.repo] mentioned earlier
serves multiple purposes. Although it is the source from which the
platform instance for pilot deployments is built, it is also the
foundation for further field trials to be carried out in 2023. Thus,
for example, there is additional software among the platform infrastructure
services (e.g., dashboard and data analysis tools) which will not be
used in the four WP6 deployments. Ditto for application services—e.g.,
Insight Generator will only be used in the lighthouse experiment.
Furthermore, the code hosted in the [kitt4sme.live repository][k4s.repo]
doubles up as a platform reference implementation that open call winners
use as a basis for further development and customisation.

Indeed, the platform has been engineered with customisation in mind,
thus it is possible to even instantiate a separate platform for each
pilot deployment. In fact, each industry partner could potentially
provision their own hardware and run the platform entirely on-premises.
Additionally, if further customisation were required, their engineers
could fork [kitt4sme.live][k4s.repo], customise their fork and then
instantiate their own platform from the fork. This process is relatively
straightforward and is the same approach adopted by open call developers.

Some of the consortium's industry partners have expressed their concerns
about their data being sent to a remote cloud (kitt4sme.collab-cloud.eu)
and processed there. The on-premises platform instantiation just outlined
provides a piece of mind solution in this case as data would never
leave company premises. However, the downside of this approach is
that running multiple cloud instances would require more hardware
and maintenance compared to a single cloud (kitt4sme.collab-cloud.eu)
shared by all the field trials.

Finally, it should be noted that each pilot deployment will require
some additional work to prepare the shop floor for the trial. The
Ideal Tek deployment is a good case in point. Rovimatica's hardware
will have to be shipped to Ideal Tek, client software installed and
calibrated, and so on. As a further example consider the Wamtechnik
deployment where the software which they have developed will need
to be configured to stream data from welding machines to the platform
instance. Although such tasks form an integral part of the pilot
deployments, they are not within the scope of this document and thus
are not covered here.




[arch.catalogue]: https://github.com/c0c0n3/kitt4sme/blob/master/arch/catalogue/README.md
[arch.cloud]: https://github.com/c0c0n3/kitt4sme/blob/master/arch/mesh/cloud.md
[bootstrap]: https://github.com/c0c0n3/kitt4sme.live/blob/main/docs/bootstrap.md
[k4s.repo]: https://github.com/c0c0n3/kitt4sme.live
