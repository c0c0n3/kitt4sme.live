Storage
-------
> Stashing our precious data away.

Since we're just getting our feet wet with the new KITT4SME platform,
we'll try keeping things simple as much as we can. That applies to
storage too. At the moment we're relying on MicroK8s built-in storage
add-on, but in the future we'll switch to network storage.


### Persistent volumes with MicroK8s storage

So how do we make data survive pod restarts? As it turns out, MicroK8s
developed their own K8s storage provider (`microk8s.io/hostpath`)
which lets you allocate physical storage directly form the box MicroK8s
runs on—in other words, the backing physical storage of PVCs is the
hard-drive of the box where MicroK8s runs.

To make it even easier to use, when you turn it on, the MicroK8s
storage add-on automatically creates a default K8s storage class
called `microk8s-hostpath` you can use right away to define a PVC,
like in the example below where we define a PVC to request 1GiB of
persistent storage.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: keycloak-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: microk8s-hostpath
  resources:
    requests:
      storage: 1Gi
```

We can then just mount a volume on a pod that references our PVC and,
voilà, whatever data the pod writes to the mount point will be saved
to the underlying hard-drive of the box MicroK8s runs on. Here's an
example where we define a volume for the Keycloak pod that uses the
PVC we defined earlier. We mount the volume on the H2 DB directory
so any data Keycloak writes to the H2 DB will be saved permanently
to physical storage. (H2 is the DB we configured Keycloak to use.)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  # ... other fields ...
spec:
  template:
    spec:
      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:16.1.0
        # ... other fields ...
        volumeMounts:
        - name: h2-volume
          mountPath: /opt/jboss/keycloak/standalone/data
      volumes:
      - name: h2-volume
        persistentVolumeClaim:
          claimName: keycloak-pvc
  # ... other fields ...
```

Here's another [example][storage.ex.default] of using the default
storage class whereas you can find an example of using a custom class
[over here][storage.ex.custom].


### A look under the bonnet

Anyways, what's happening under the bonnet? Let's see. After applying
the two K8s manifests above, we'd expect a PV and PVC to be created.
In fact, that's the case.

```console
$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS        REASON   AGE
pvc-d4d014e7-253e-4b5b-b4a7-10b1425746cd   1Gi        RWO            Delete           Bound    default/keycloak-pvc   microk8s-hostpath            3h11m
```

```console
$ kubectl describe pv pvc-d4d014e7-253e-4b5b-b4a7-10b1425746cd
Name:            pvc-d4d014e7-253e-4b5b-b4a7-10b1425746cd
Labels:          <none>
Annotations:     hostPathProvisionerIdentity: kitt4sme
                 pv.kubernetes.io/provisioned-by: microk8s.io/hostpath
Finalizers:      [kubernetes.io/pv-protection]
StorageClass:    microk8s-hostpath
Status:          Bound
Claim:           default/keycloak-pvc
Reclaim Policy:  Delete
Access Modes:    RWO
VolumeMode:      Filesystem
Capacity:        1Gi
Node Affinity:   <none>
Message:
Source:
    Type:          HostPath (bare host directory volume)
    Path:          /var/snap/microk8s/common/default-storage/default-keycloak-pvc-pvc-d4d014e7-253e-4b5b-b4a7-10b1425746cd
    HostPathType:
Events:            <none>
```

But hang on. Who's doing that?! Um, let's see.

```console
$ kubectl -n kube-system get pods
NAME                                      READY   STATUS    RESTARTS   AGE
hostpath-provisioner-5c65fbdb4f-rv2qn     1/1     Running   3          55d
...
```

Ha! See that `hostpath-provisioner` guy? That's the service the storage
add-on deploys and which supposedly manages the physical storage. Let's
make it spill the beans.

```console
$ kubectl -n kube-system logs hostpath-provisioner-5c65fbdb4f-rv2qn
I0114 19:32:27.236036       1 controller.go:293] Starting provisioner controller b4d60bf4-7570-11ec-b9fd-16404758c316!
I0119 13:14:26.182586       1 controller.go:893] scheduleOperation[lock-provision-default/keycloak-pvc[d4d014e7-253e-4b5b-b4a7-10b1425746cd]]
I0119 13:14:26.188243       1 controller.go:893] scheduleOperation[lock-provision-default/keycloak-pvc[d4d014e7-253e-4b5b-b4a7-10b1425746cd]]
I0119 13:14:26.220118       1 leaderelection.go:154] attempting to acquire leader lease...
I0119 13:14:26.270546       1 leaderelection.go:176] successfully acquired lease to provision for pvc default/keycloak-pvc
I0119 13:14:26.273359       1 controller.go:893] scheduleOperation[provision-default/keycloak-pvc[d4d014e7-253e-4b5b-b4a7-10b1425746cd]]
I0119 13:14:26.307956       1 hostpath-provisioner.go:86] creating backing directory: /var/snap/microk8s/common/default-storage/default-keycloak-pvc-pvc-d4d014e7-253e-4b5b-b4a7-10b1425746cd
I0119 13:14:26.327887       1 controller.go:627] volume "pvc-d4d014e7-253e-4b5b-b4a7-10b1425746cd" for claim "default/keycloak-pvc" created
I0119 13:14:26.499739       1 controller.go:644] volume "pvc-d4d014e7-253e-4b5b-b4a7-10b1425746cd" for claim "default/keycloak-pvc" saved
I0119 13:14:26.499776       1 controller.go:680] volume "pvc-d4d014e7-253e-4b5b-b4a7-10b1425746cd" provisioned for claim "default/keycloak-pvc"
I0119 13:14:28.297817       1 leaderelection.go:196] stopped trying to renew lease to provision for pvc default/keycloak-pvc, task succeeded
```

If you eyeball the log, you should be able to make sense of it all.




[storage.ex.custom]: https://igy.cx/posts/setup-microk8s-rbac-storage/
[storage.ex.default]: https://www.server-world.info/en/note?os=Ubuntu_20.04&p=microk8s&f=5
