#!/bin/bash
###########

USED_IMAGE=$(kubectl get pods -n kube-public -l app=hello-world-company -o=jsonpath='{.items[0].spec.containers[0].image}')
UPDATE_IMAGE="gcr.io/a506-till/hello-company:with-gs-v2"
if [ "${USED_IMAGE}" = "gcr.io/a506-till/hello-company:with-gs-v2" ]
then
  UPDATE_IMAGE="gcr.io/a506-till/hello-company:with-gs-v1"
else
  UPDATE_IMAGE="gcr.io/a506-till/hello-company:with-gs-v2"
fi

updatePod() {
  kubectl set image deployment/hello-world-company hello-world=$UPDATE_IMAGE  -n kube-public  > /dev/null 2>&1 
}

echo "開始壓測200人不間斷40秒  kubectl run --rm=true -i -t siege -n kube-public --image=yokogawa/siege -- -b --time=40S -c200 http://hello-world-company.kube-public.svc.cluster.local:8080/hello"
echo "更版Pod的Image           kubectl set image deployment/hello-world-company hello-world=$UPDATE_IMAGE" -n kube-public
updatePod &
echo "查看壓測Logs，40秒後產生結果"
kubectl run --rm=true -i -t siege -n kube-public --image=yokogawa/siege -- -b --time=60S -c100 http://hello-world-company.kube-public.svc.cluster.local:8080/hello