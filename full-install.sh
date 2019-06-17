#!/usr/bin/env bash
###########
# 安裝 K8S+Istio+Jenkins 課程環境
###

# 確認 gcloud 指令已經 login
checkGcloudLogin() {
  if [ `gcloud config get-value core/account | grep 'compute@developer.gserviceaccount.com' | wc -l` -eq 1 ]; then
    echo "[ERROR] gcloud 指令尚未登入"
    echo "        請先執行以下指令，登入 gcloud 後再重試 "
    echo "------------------------------------------"
    echo "gcloud auth login"
    echo "------------------------------------------"
    exit
  fi
}

# 設定參數
initParameter() {
  echo "參數設定確認中..."
  
  GOOGLE_PROJECT_ID=$(gcloud projects list --filter=systex-lab  | awk 'END {print $1}')
  
  # GOOGLE_PROJECT_ID
  if [ -z $GOOGLE_PROJECT_ID  ]; then
    GOOGLE_PROJECT_ID=systex-lab-$(cat /proc/sys/kernel/random/uuid | cut -b -6)
    echo "  未定義 GOOGLE_PROJECT_ID.   由系統自動產生...(GOOGLE_PROJECT_ID=$GOOGLE_PROJECT_ID)" 
  else
    echo "  系統參數 GOOGLE_PROJECT_ID  已設定...........(GOOGLE_PROJECT_ID=$GOOGLE_PROJECT_ID)" 
  fi
  
  # GOOGLE_ZONE
  if [ -z $GOOGLE_ZONE  ]; then
    GOOGLE_ZONE=asia-east1-$(ary=(a b c) && echo ${ary[$(($RANDOM%3))]})
    echo "  未定義 GOOGLE_ZONE.         使用預設值.......(GOOGLE_ZONE=$GOOGLE_ZONE)"
  else
    echo "  系統參數 GOOGLE_ZONE        已設定...........(GOOGLE_ZONE=$GOOGLE_ZONE)" 
  fi
  
  # GOOGLE_GKE_NAME
  if [ -z $GOOGLE_GKE_NAME  ]; then
    GOOGLE_GKE_NAME=devops-camp
    echo "  未定義 GOOGLE_GKE_NAME.     使用預設值.......(GOOGLE_GKE_NAME=$GOOGLE_GKE_NAME)"
  else
    echo "  系統參數 GOOGLE_GKE_NAME    已設定...........(GOOGLE_GKE_NAME=$GOOGLE_GKE_NAME)" 
  fi

  # GOOGLE_GKE_MACHINE
  if [ -z $GOOGLE_GKE_MACHINE  ]; then
    GOOGLE_GKE_MACHINE=n1-standard-2
    echo "  未定義 GOOGLE_GKE_MACHINE.  使用預設值.......(GOOGLE_GKE_MACHINE=$GOOGLE_GKE_MACHINE)"
  fi

  # GOOGLE_GKE_NODES
  if [ -z $GOOGLE_GKE_NODES  ]; then
    GOOGLE_GKE_NODES=3
    echo "  未定義 GOOGLE_GKE_NODES.    使用預設值.......(GOOGLE_GKE_NODES=$GOOGLE_GKE_NODES)"
  fi

  # GOOGLE_GCE_IMAGE
  if [ -z $GOOGLE_GKE_VERSION  ]; then
    GOOGLE_GKE_VERSION=1.12.8-gke.6
    echo "  未定義 GOOGLE_GKE_VERSION.  使用預設值.......(GOOGLE_GKE_VERSION=$GOOGLE_GKE_VERSION)"
  fi

  # HELM_VERSION
  if [ -z $HELM_VERSION  ]; then
    HELM_VERSION=v2.13.1
    echo "  未定義 HELM_VERSION.        使用預設值.......(HELM_VERSION=$HELM_VERSION)"
  fi

  # ISTIO_VERSION
  if [ -z $ISTIO_VERSION  ]; then
    ISTIO_VERSION=1.0.8
    echo "  未定義 ISTIO_VERSION.       使用預設值.......(ISTIO_VERSION=$ISTIO_VERSION)"
  fi

  read -p "確認開始安裝(Y/n)?" yn
  case $yn in
      [Nn]* ) echo "動作取消 "; exit;;
  esac  
}

# 安裝 kubectl 指令
installKubectl() {
  echo "正在安裝 kubectl 指令..."
  printf "  安裝 kubectl 套件中......"
  yum -y install kubectl > /dev/null 2>&1 && echo "完成"
}

createProject() {
  echo "正在建立GCP 專案..."
  gcloud projects create $GOOGLE_PROJECT_ID > /dev/null 2>&1
  echo "export \$(cat .my-env|xargs)" | tee -a ~/.profile > /dev/null 2>&1

  printf "  切換專案至($GOOGLE_PROJECT_ID)..."
  gcloud config set project $GOOGLE_PROJECT_ID > /dev/null 2>&1 && echo "完成"
    
    
  BILLING_ACCOUNT=$(gcloud beta billing accounts list | grep True | awk -F" " '{print $1}')
  gcloud beta billing projects link $GOOGLE_PROJECT_ID --billing-account $BILLING_ACCOUNT > /dev/null 2>&1
}

createK8S() {
  echo "正在建立GKE..."
  
  printf "  啟用 Container API..."
  gcloud services enable container.googleapis.com --project=$GOOGLE_PROJECT_ID  > /dev/null 2>&1 && echo "完成"

  printf "  開始建立 GKE($GOOGLE_GKE_NAME)..."
  if [ $(gcloud container clusters list --project=$GOOGLE_PROJECT_ID | grep $GOOGLE_GKE_NAME | wc -l) -eq 0 ]; then
    gcloud container clusters create $GOOGLE_GKE_NAME \
        --project=$GOOGLE_PROJECT_ID \
        --machine-type=$GOOGLE_GKE_MACHINE \
        --zone=$GOOGLE_ZONE \
        --num-nodes=$GOOGLE_GKE_NODES \
        --cluster-version=$GOOGLE_GKE_VERSION \
        --disk-type "pd-standard" \
        --disk-size "500" \
        > /dev/null 2>&1 && echo "完成"
  else
    echo "已存在"
  fi
  
  printf "  正在設定授權..."
  kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole=cluster-admin \
    --user=$(gcloud config get-value core/account)\
    > /dev/null 2>&1 && echo "完成"

}

installHelm() {
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
  kubectl create sa jenkins-deployer
  kubectl create clusterrolebinding jenkins-deployer-role --clusterrole=cluster-admin --serviceaccount=default:jenkins-deployer
  K8S_ADMIN_CREDENTIAL=$(kubectl describe secret jenkins-deployer | grep token: | awk -F" " '{print $2}')
  cat <<EOF | kubectl apply -f -
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

  git clone https://github.com/bryanwu66/devops-hands-on.git
  helm install --name jenkins \
    --set Master.K8sAdminCredential=$K8S_ADMIN_CREDENTIAL \
    devops-hands-on/jenkins
}

installIstio() {

  curl -s -L https://git.io/getLatestIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
  cd istio-1.0.8

  kubectl create namespace istio-system
  cat <<EOF | kubectl apply -f -
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
  passphrase: YWRtaW4=
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
  |  kubectl apply -f -
  kubectl label namespace default istio-injection=enabled

  kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
  kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
  kubectl apply -f samples/bookinfo/networking/destination-rule-all.yaml
}

initParameter
createProject
createK8S
installHelm
installJenkins
installIstio

> ~/.my-env
echo "GOOGLE_PROJECT_ID=$GOOGLE_PROJECT_ID" >> ~/.my-env
echo "GOOGLE_ZONE=$GOOGLE_ZONE" >> ~/.my-env
echo "GOOGLE_GKE_NAME=$GOOGLE_GKE_NAME" >> ~/.my-env


#cat <<EOF
#----------------------------------------
#環境安裝完成
#----------
#GCP 專案名稱: $GOOGLE_PROJECT_ID
#GKE 叢集名稱: $GOOGLE_GKE_NAME
#GKE 地區    : $GOOGLE_ZONE
#GKE 版本    : $GOOGLE_GKE_VERSION
#----------------------------------------
#請執行以下指令，完成環境設置
#-----------------------
#export \$(cat .my-env|xargs)
#----------------------------------------
#EOF
