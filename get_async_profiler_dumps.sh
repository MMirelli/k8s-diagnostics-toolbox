#!/usr/bin/env bash
: "${CLEANUP_PREVIOUS_JFR:=1}"
components=${1}

bin_filename="exec-k8s-diagnostics-toolbox.sh"
tmp_filename="/tmp/${bin_filename}"
echo "Storing script to execute remotely in ${tmp_filename}"

(cat <<- "EOF"
#!/bin/bash
set -x
target_pod=${1}
export HOME=/home/kubernetes/bin/k8sdiag;
if [[ ! -d '/home/kubernetes/bin/k8sdiag' ]] ; then
  sudo mkdir -p /home/kubernetes/bin/k8sdiag;
  cd;
  sudo mkdir -p ~/k8s-diagnostics-toolbox && \
    cd ~/k8s-diagnostics-toolbox && \
    curl -L https://github.com/MMirelli/k8s-diagnostics-toolbox/archive/refs/heads/patchedmaster.tar.gz | \
      sudo tar -zxv --strip-components=1 -f -;
else
  echo 'k8s-diagnostics-toolbox installed'
fi;
cd ${HOME}/k8s-diagnostics-toolbox
ls ${HOME}/k8s-diagnostics-toolbox
./k8s-diagnostics-toolbox.sh async_profiler ${target_pod} -t -e cpu,lock,alloc -d 20 -f /tmp/on-fly-profiling.jfr jps
set +x
EOF
) > "${tmp_filename}"
if [[ $INSTALL_OPENJDK -eq 1 ]]; then
    for pod in $(kubectl get po -o name -l "component in (${components})"  -n pulsar); do
        kubectl exec -it -n pulsar $pod -- bash -c "apt update && apt install -y openjdk-11-dbg" &
        pid[$i]=$!
    done
fi
for ((i = 1; i <= ${#pid[@]}; i++)); do
    echo "Process ${pid[$i]} terminated"
    wait ${pid[$i]}
done
echo 'Installation terminated'
pid=
for target_pod in $(kubectl get -n pulsar pod -l app="pulsar,component in (${components})" -o jsonpath='{.items[*].metadata.name}'); do
    target_node="$(kubectl get -n pulsar pod "${target_pod}" -o jsonpath='{.spec.nodeName}')"
    full_gcp_zone_target_node="$(gcloud compute instances describe ${target_node} | yq e '.zone')"
    zone_target_node=${full_gcp_zone_target_node/*zones\/}
    echo "Getting JFR profiling of ${target_pod}, running on ${target_node} in zone ${zone_target_node}"
    gcloud compute scp "${tmp_filename}" "root@${target_node}:/root" \
           --zone "${zone_target_node}" -q 2> /dev/null && \
        gcloud compute ssh "root@${target_node}" \
               --zone "${zone_target_node}" \
               --command="sudo chmod +x /root/${bin_filename} \
                                          && /root/${bin_filename} ${target_pod}" --zone "${zone_target_node}" -q 2> /dev/null && \
        gcloud compute scp "root@${target_node}:/home/kubernetes/bin/k8sdiag/k8s-diagnostics-toolbox/*.jfr" \
               /tmp/ --zone "${zone_target_node}" &
    pid[$i]=$!
done
for ((i = 1; i <= ${#pid[@]}; i++)); do
    echo "Process ${pid[$i]} terminated"
    wait ${pid[$i]}
done
