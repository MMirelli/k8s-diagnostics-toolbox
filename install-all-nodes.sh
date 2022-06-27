#!/bin/bash

PROVIDER=${1:-GKE}
if [[ $PROVIDER == "GKE" ]]; then
    cmd="sudo mkdir -p /home/kubernetes/bin/k8sdiag; export HOME=/home/kubernetes/bin/k8sdiag; sudo cd; sudo mkdir -p ~/k8s-diagnostics-toolbox && cd ~/k8s-diagnostics-toolbox && curl -L https://github.com/lhotari/k8s-diagnostics-toolbox/archive/refs/heads/master.tar.gz | sudo tar -zxv --strip-components=1 -f -"
else
    cmd="sudo mkdir -p ~/k8s-diagnostics-toolbox && cd ~/k8s-diagnostics-toolbox && curl -L https://github.com/lhotari/k8s-diagnostics-toolbox/archive/refs/heads/master.tar.gz | sudo tar -zxv --strip-components=1 -f -"
fi

for node in $(kubectl get nodes -o name); do
    node=${node/node\//}
    echo "Executing $cmd on $node"
    gcloud compute ssh $node --command="$cmd"
done

