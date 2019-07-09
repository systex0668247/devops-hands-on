#!/usr/bin/env bash
###########
# 安裝 Lab(k8s) 課程環境
###

#!/usr/bin/env bash
###########
# 專案 AWS 建立
###
AWS_REGION=us-west-2
AWS_ACCOUT_ID=348053640110
CURRENT_HOME=$(pwd)


initialclient(){
# 安裝aws cli
sudo apt-get -y install python3.6 python3-pip
pip3 install awscli --upgrade --user
echo "到AWS 的IAM 上取得帳號的 Access Key ID 和 Secret access key"

# 確認使用者是否登入
echo "輸入剛剛取得的 Access Key ID 和 Secret access key"
aws configure
}

# Install eks
installeks() {
cd $CURRENT_HOME
# 下載安裝包
git clone https://github.com/harryliu123/eks-templates
cd eks-templates
# 建立VPC
export VPC_STACK_NAME=eks-service
aws cloudformation create-stack  --stack-name ${VPC_STACK_NAME} --template-body file://eks-vpc.yaml --region $AWS_REGION
sleep 5
vpcid=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=${VPC_STACK_NAME}-VPC |jq -r  '.Vpcs[].VpcId')
Subnet01=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=${VPC_STACK_NAME}-Subnet01 |jq -r '.Subnets[].SubnetId')
Subnet02=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=${VPC_STACK_NAME}-Subnet02 |jq -r '.Subnets[].SubnetId')
Subnet03=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=${VPC_STACK_NAME}-Subnet03 |jq -r '.Subnets[].SubnetId')

# AmazonEKSAdminRole IAM Role
iamrole=$(aws iam get-role --role-name AmazonEKSAdminRole --query 'Role.Arn' --output text)

# 部屬 EKS
REGION=$AWS_REGION EKS_ADMIN_ROLE=$iamrole VPC_ID=$vpcid SUBNET1=$Subnet01 SUBNET2=$Subnet02 SUBNET3=$Subnet03  make create-eks-cluster
}

# 確認CloudFormation 狀態是否完成
checkeksstatus() {
while [ $(aws cloudformation describe-stacks --stack-name eksdemo |jq -r '.Stacks[].StackStatus') != 'CREATE_COMPLETE' ]
do
   sleep 10
done
}

# 新建ECR
createecr() {
aws ecr create-repository --repository-name ecr --region $AWS_REGION
$(aws ecr get-login --no-include-email --region $AWS_REGION)
echo "ecr的 token 在 $CURRENT_HOME/.docker/config.json"
}


# 安裝 kubectl 指令
installKubectl() {
  echo "正在安裝 kubectl 指令..."
  printf "  安裝 kubectl 套件中......"
  apt-get -y install kubectl > /dev/null 2>&1 && echo "完成"
}

# 執行更新IAM role
updaterole(){
cd $CURRENT_HOME/eks-templates
aws iam update-assume-role-policy --role-name AmazonEKSAdminRole --policy-document file://assume-role-policy.json
}

# 更新kubectl configure
updatekubectlconfigure() {
cd $CURRENT_HOME/eks-templates
# AmazonEKSAdminRole IAM Role
iamrole=$(aws iam get-role --role-name AmazonEKSAdminRole --query 'Role.Arn' --output text)
aws --region us-east-2 eks update-kubeconfig --name eksdemo --role-arn $iamrole
}



installHelm() {

  cd $CURRENT_HOME

  echo "安裝 Helm ..."
  printf "  正在下載 Helm($HELM_VERSION)..."
  curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get | DESIRED_VERSION=$HELM_VERSION bash > /dev/null 2>&1
  helm init > /dev/null 2>&1 && echo "完成"

  printf "  正在授權 Tiller..."
  kubectl create serviceaccount --namespace kube-system tiller > /dev/null 2>&1
  kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller > /dev/null 2>&1
  kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}' \
  > /dev/null 2>&1 && echo "完成"

  printf "  等待 Tiller 服務啟動中 ..."
  while [ `kubectl get po -n kube-system | grep tiller-deploy | grep '1/1' | wc -l` -eq 0 ]
  do
    sleep 1
  done
  echo "已啟動."
}

installJenkins() {
  cd $CURRENT_HOME

  echo "安裝 Jenkins ..."

  printf "  正在授權 jenkins-deployer..."

  # Google Container Registry 
  gcloud iam service-accounts create jenkins-deployer > /dev/null 2>&1
  #gsutil iam ch serviceAccount:jenkins-deployer@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com:admin gs://artifacts.${GOOGLE_PROJECT_ID}.appspot.com/  > /dev/null 2>&1
  gcloud projects add-iam-policy-binding ${GOOGLE_PROJECT_ID} \
      --member="serviceAccount:jenkins-deployer@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com" \
      --role='roles/storage.admin' > /dev/null 2>&1
  gcloud iam service-accounts keys create key.json --iam-account=jenkins-deployer@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com > /dev/null 2>&1
  docker login -u _json_key -p "$(cat key.json)" https://gcr.io  > /dev/null 2>&1
  kubectl create configmap google-container-key --from-file=.docker/config.json  > /dev/null 2>&1

  kubectl create sa jenkins-deployer > /dev/null 2>&1
  kubectl create clusterrolebinding jenkins-deployer-role --clusterrole=cluster-admin --serviceaccount=default:jenkins-deployer > /dev/null 2>&1
  K8S_ADMIN_CREDENTIAL=$(kubectl describe secret jenkins-deployer | grep token: | awk -F" " '{print $2}')
  cat <<EOF | kubectl apply -f -  > /dev/null 2>&1 && echo "完成"
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: fabric8-rbac
subjects:
  - kind: ServiceAccount
    name: default
    namespace: default
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

  printf "  正在安裝 jenkins-slave ... "
  printf "build..." && docker build -t gcr.io/${GOOGLE_PROJECT_ID}/jnlp-slave:v1 devops-hands-on/jenkins/slave > /dev/null 2>&1
  printf "push..." && docker push gcr.io/${GOOGLE_PROJECT_ID}/jnlp-slave:v1 > /dev/null 2>&1
  echo "完成"

  printf "  正在安裝 jenkins:lts ..."
  helm install --name jenkins \
    --set Master.ServiceType=ClusterIP \
    --set Master.K8sAdminCredential=$K8S_ADMIN_CREDENTIAL \
    --set Agent.Image=gcr.io/${GOOGLE_PROJECT_ID}/jnlp-slave \
    --set Agent.ImageTag=v1 \
    --set Master.AdminPassword=systex \
    --set Master.GoogleProjectId=${GOOGLE_PROJECT_ID} \
    devops-hands-on/jenkins > /dev/null 2>&1 && echo "完成"
}

installIstio() {
  cd $CURRENT_HOME

  echo "安裝 Istio ..."

  printf "  正在下載 Istio:$ISTIO_VERSION ..."
  curl -s -L https://git.io/getLatestIstio | ISTIO_VERSION=$ISTIO_VERSION sh - > /dev/null 2>&1 && echo "完成"
  cd istio-$ISTIO_VERSION
  
  printf "  開始安裝 Istio ..."
  kubectl create namespace istio-system > /dev/null 2>&1 
  cat <<EOF | kubectl apply -f - > /dev/null 2>&1 
apiVersion: v1
kind: Secret
metadata:
  name: kiali
  namespace: istio-system
  labels:
    app: kiali
type: Opaque
data:
  username: YWRtaW4=
  passphrase: c3lzdGV4
EOF
  #helm template install/kubernetes/helm/istio-init --name istio-init --namespace istio-system | kubectl apply -f -
  helm template install/kubernetes/helm/istio \
    --name istio --namespace istio-system \
    --set sidecarInjectorWebhook.enabled=true \
    --set pilot.traceSampling=100.0 \
    --set pilot.resources.requests.cpu=100m \
    --set pilot.resources.requests.memory=256Mi \
    --set grafana.enabled=true \
    --set tracing.enabled=true \
    --set servicegraph.enabled=true \
    --set kiali.enabled=true \
    --set kiali.createDemoSecret=true \
  |  kubectl apply -f - > /dev/null 2>&1
  printf "等待服務啟動中..."
  while [ `kubectl get po -n istio-system | grep istio-sidecar-injector | grep Running | grep '1/1' | wc -l` -eq 0 ]
  do
    sleep 1
  done  
  echo "完成"

  printf "  設定自動注入 sidecar ..."
  kubectl label namespace default istio-injection=enabled > /dev/null 2>&1 && echo "完成"

  printf "  安裝 Bookinfo 範例程式 ..."
  kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml > /dev/null 2>&1
  kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml > /dev/null 2>&1
  kubectl apply -f samples/bookinfo/networking/destination-rule-all.yaml > /dev/null 2>&1 && echo "完成"
}

installEFK() {
  cd $CURRENT_HOME

  echo "安裝 Elasticsearch + Fluentd + Kibana ..."
  printf "  安裝中 ..."
  kubectl apply -f devops-hands-on/logging-efk.yaml > /dev/null 2>&1 && echo "完成"

}



installKSM() {
  cd $CURRENT_HOME

  echo "安裝 Kube-state-metrics ..."
  printf "  安裝中 ..."
  kubectl apply -f devops-hands-on/kube-state-metrics/app-crd.yaml > /dev/null 2>&1 
  kubectl apply -f devops-hands-on/kube-state-metrics/prometheus-metrics_sa_manifest.yaml --namespace logging > /dev/null 2>&1 
  kubectl apply -f devops-hands-on/kube-state-metrics/prometheus-metrics_manifest.yaml --namespace logging  > /dev/null 2>&1 && echo "完成"

}

confirmInstall() {
  cd $CURRENT_HOME
  
  echo "確認安裝項目清單"
  
  printf "  GCP Project($GOOGLE_PROJECT_ID) ............."
  if [ $(gcloud projects list | grep $GOOGLE_PROJECT_ID | wc -l ) -eq 1 ]; then
    echo "完成."
  else 
    echo "失敗."
  fi
  printf "  GCP Kubernetes Cluster($GOOGLE_GKE_NAME) ........"
  if [ $(gcloud container clusters list | grep $GOOGLE_GKE_NAME | wc -l ) -eq 1 ]; then
    echo "完成."
  else 
    echo "失敗."
  fi

  printf "  Istio System ..............................."
  if [ $(kubectl get po -n istio-system | grep -E "servicegraph|prometheus|kiali|tracing|telemetry|sidecar|policy|egressgateway|galley|ingressgateway|pilot" | wc -l ) -ge 11 ]; then
    echo "已安裝."
  else 
    echo "失敗."
  fi

  printf "  Elasticsearch+Kibana+Fluentd ..............."
  if [ $(kubectl get po -n logging | grep -E "elasticsearch|kibana|fluentd" | wc -l ) -eq 3 ]; then
    echo "已安裝."
  else 
    echo "失敗."
  fi

  printf "  Kube state metrics ........................."
  if [ $(kubectl get po -n logging | grep "prometheus-metrics" | wc -l ) -ge 5 ]; then
    echo "已安裝."
  else 
    echo "失敗."
  fi

  printf "  Jenkins ...................................."
  if [ $(helm list | grep jenkins | wc -l ) -eq 1 ]; then
    echo "已安裝."
  else 
    echo "失敗."
  fi  
}

setupService() {
  cd $CURRENT_HOME
  
  echo "設定對外服務項目..."
  
  printf "  等待對外IP配發中..."
  while [ `kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' | wc -c` -eq 0 ]
  do
    sleep 1
  done  
  INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  echo "(IP=$INGRESS_HOST)...完成"

  printf "  開啟對外服務中..."
  helm template --set istio.ingressgateway.ip=$INGRESS_HOST devops-hands-on/svc | kubectl apply -f - > /dev/null 2>&1 && echo "完成"
}

CURRENT_HOME=$(pwd)

rm -rf ~/.my-env
rm -rf key.json
rm -rf devops-hands-on

git clone https://github.com/abola/devops-hands-on.git


initialclient
installeks
checkeksstatus
createecr
installKubectl
updaterole
updatekubectlconfigure

installHelm
installJenkins
installIstio
installEFK
installKSM
setupService
confirmInstall

> ~/.my-env
echo "GOOGLE_PROJECT_ID=$GOOGLE_PROJECT_ID" >> ~/.my-env
echo "GOOGLE_ZONE=$GOOGLE_ZONE" >> ~/.my-env
echo "GOOGLE_GKE_NAME=$GOOGLE_GKE_NAME" >> ~/.my-env
echo "INGRESS_HOST=$INGRESS_HOST" >> ~/.my-env

cat <<EOF
-------------------------------------------------------------
環境安裝完成
----------
Istio Bookinfo 示範程式: http://bookinfo.$INGRESS_HOST.nip.io/
K8S Health Monitoring  : http://grafana.$INGRESS_HOST.nip.io/
Kiali Service Graph    : http://kiali.$INGRESS_HOST.nip.io/
Jaeger Tracing         : http://jaeger.$INGRESS_HOST.nip.io/
Kibana Logging         : http://kibana.$INGRESS_HOST.nip.io/
Jenkins CI/CD          : http://jenkins.$INGRESS_HOST.nip.io/
-------------------------------------------------------------
EOF
