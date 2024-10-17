# K3S-Cluster-Arm
There are multiple implementations out [there](https://github.com/rootsongjc/kubernetes-vagrant-centos-cluster) to run and setup your local k8s cluster, as a DevOps you want to have a safe lab to experiment with new plugins, charts make mistakes and so on. Until know, spining vms using Vagrant was the way for me (been using intel macbook), but since my last change of computer, the cpu arch/chip change everything. For an apple silicon M1 chips at this moment is not supported or it contains to many errors in the hypervisor Virtualbox.

This repo only contains a basic shell script to spin up a k3s cluster using multipass from Canonical(ubuntu vms), this allows you to Launch instances of Ubuntu and initialise them with cloud-init metadata in the same way you would do on AWS, Azure, Google, IBM and Oracle. Simulate your own cloud deployment on your workstation and it works with the Mx Apple silicon chips, it is really light weight and fast.

Also if you want other option you could check the kind or may be the following  [repo with istio support](https://github.com/rootsongjc/cloud-native-sandbox)

## How to use it:
You just need to clone this repo, here is an example how you can use this k3s provisioner :

[![asciicast](https://asciinema.org/a/Am6Cxfrj3VZBUF2xSNicNV6NI.svg)](https://asciinema.org/a/Am6Cxfrj3VZBUF2xSNicNV6NI)

This will create a basic cluster where you can use this to play with the different k8s objects out there.

```shell
./provisioner
```

