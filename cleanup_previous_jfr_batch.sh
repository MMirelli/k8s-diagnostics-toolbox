#!/usr/bin/env bash
components=${1}
for target_pod in $(kubectl get -n pulsar pod -l app="pulsar,component in (${components})" -o jsonpath='{.items[*].metadata.name}'); do
    target_node="$(kubectl get -n pulsar pod "${target_pod}" -o jsonpath='{.spec.nodeName}')"
    full_gcp_zone_target_node="$(gcloud compute instances describe ${target_node} | yq e '.zone')"
    zone_target_node=${full_gcp_zone_target_node/*zones\/}
    echo "Deleting old JFR profiling of ${target_pod}, running on ${target_node} in zone ${zone_target_node}"
    gcloud compute ssh "root@${target_node}" \
           --zone "${zone_target_node}" \
           --command="rm /home/kubernetes/bin/k8sdiag/k8s-diagnostics-toolbox/*.jfr; ls /home/kubernetes/bin/k8sdiag/k8s-diagnostics-toolbox/" &
    pid[$i]=$!
done
for ((i = 1; i <= ${#pid[@]}; i++)); do
    echo "Process ${pid[$i]} terminated"
    wait ${pid[$i]}
done
rm /tmp/*.jfr
