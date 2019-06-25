#!/bin/bash
###########

INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
POD_ID=$(kubectl get pods -n kube-public -l app=hello-world-company -o=jsonpath='{.items[*].metadata.name}')

callLong() {
  curl http://$INGRESS_HOST/long
}

deletePod() {
  sleep 5
  kubectl delete pod $POD_ID -n kube-public   > /dev/null 2>&1
}

echo "呼叫需執行20秒的任務...    http://$INGRESS_HOST/long "
callLong &
echo "等待5秒後刪除正在執行的Pod kubectl delete pod $POD_ID -n kube-public"
deletePod &
echo "查看Pod的運作Logs          kubectl logs -f $POD_ID -c hello-world -n kube-public"
kubectl logs -f $POD_ID -c hello-world -n kube-public
wait 