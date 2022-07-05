Hand tools
----------
> Ideal Tek field trial (Task 6.2)


Some initial notes about how Ideal Tek can take advantage of VIQE in
a real work environment. Plus action points to be converted to GitHub
issues we can work on.


### Tip alignment & dimensions

#### Goal
Currently operators do a manual visual inspection to check if tweezers
features such as tip alignment and dimensions conform to product specs.
Cognitive bias could affect quality control. The goal is to put in place
a solution operators can rely on to get an **objective** assessment of
whether dimensions conform to product specs.

#### Workflow
The operator puts the tweezers to analyse in a purposely assembled
quality control machine, QCM. Metro-VIQE, installed on a workstation
directly connected to QCM, orchestrates image & measurement acquisition
from QCM with some input from the operator (since this is a mutli-stage
process), analyses the data locally and eventually sends an inspection
report to the KITT4SME platform---deployed remotely in the cloud. The
operator gets instant feedback about tweezers conformance to product
specs from Metro-VIQE and also has access to a dashboard running in
the KITT4SME cloud where inspection reports are displayed.

#### Hardware
Rovimatica will assemble QCM, complete with Dino-Lite microscope and
camera, and ship it to Ideal Tek. Ideal Tek will provision a workstation
where to install Metro-VIQE and network connectivity to the KITT4SME
cloud.

#### Software
The only software to install on premises is Metro-VIQE---and possibly
the workstation operating system. Metro-VIQE ships preconfigured with
the product specs Ideal Tek would like to use for quality inspection.
Additional environment configuration may be needed---network, device
connections, etc.


### Surface quality assessment

The arrangement here is pretty much the same as the above, but the
local VIQE software to be used is Smart-VIQE. No need to spell more
ink on this :-)


### Action points

* Ideal Tek to send Rovimatica tweezers samples.
* Rovimatica to plan for an alpha release possibly with alot of features
  still missing but where we can test the on-prems installation procedure.
* Rovimatica to send their staff over to Switzerland for installation
  or alternatively train me so I can do the installation myself.
* Rovimatica to provide Ideal Tek with workstation specs---CPU, RAM,
  hard drive, network, operating system, cabling.
