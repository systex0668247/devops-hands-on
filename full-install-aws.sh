#!/usr/bin/env bash
#############################################################################
# 安裝 Lab(k8s) 課程環境，在AWS 建立 EKS & keycloak
#############################################################################

############################################################################
# 填寫必要變數   
############################################################################

AWS_REGION=<輸入要在哪個region建立>              # AWS Region，例如 us-west-2  https://docs.aws.amazon.com/zh_cn/AWSEC2/latest/UserGuide/using-regions-availability-zones.html
AWS_ACCOUNT_ID=<輸入自己的accout_id>              # root User ID，例如 348053640110
iamuseraccount=<請變更自己的AWS上的IAM user>     # IAM 使用者名稱，例如 A506-Harry
# 執行 Script 時會需要在 互動介面輸入 AWS 程式存取金鑰，請事先產生及複製保存 Access Key ID 和 Secret access key
CURRENT_HOME=$(pwd)                              # 設定家目錄為預設工作目錄的參數
VPC_STACK_NAME=<vpc-name>                        # 輸入VPC的名稱
CLUSTER_STACK_NAME=<eksname>                     # 輸入eks的叢集名稱
##########################
### 逐步執行的function
##########################
main() {
initialclientcloudshell
installeks
checkeksstatus
createecr
installKubectl
updaterole
updatekubectlconfigure
createiamgroup
installkeycloak
InstallEcrJenkins
installistio
installEFK
installKSM
setupService
# createhaproxy

> ~/.my-env
echo "INGRESS_HOST=$INGRESS_HOST" >> ~/.my-env
cat <<EOF
-------------------------------------------------------------
環境安裝完成
-------------------------------------------------------------
Istio Bookinfo 示範程式: http://bookinfo.$INGRESS_HOST.nip.io/
K8S Health Monitoring  : http://grafana.$INGRESS_HOST.nip.io/
Kiali Service Graph    : http://kiali.$INGRESS_HOST.nip.io/
Jaeger Tracing         : http://jaeger.$INGRESS_HOST.nip.io/
Kibana Logging         : http://kibana.$INGRESS_HOST.nip.io/
Jenkins CI/CD          : http://jenkins.$INGRESS_HOST.nip.io/
Keycloak               : http://keycloak.$INGRESS_HOST.nip.io/
-------------------------------------------------------------
EOF
}


initialclientcloudshell(){
# 安裝aws cli on GCP上的 cloudshell
sudo apt-get -y install python3.6 python3-pip  > /dev/null 2>&1
pip3 install awscli --upgrade --user  > /dev/null 2>&1
echo "請到 AWS 的IAM 上取得帳號的 Access Key ID 和 Secret access key"

# 確認使用者是否登入
echo "請於下列互動介面輸入剛剛取得 AWS 的 Access Key ID 和 Secret access key"
aws configure
}

# Install eks
installeks() {
cd $CURRENT_HOME
# 下載安裝包
git clone https://github.com/harryliu123/eks-templates
cd eks-templates
# 建立VPC
aws cloudformation create-stack  --stack-name ${VPC_STACK_NAME} --template-body file://eks-vpc.yaml --region $AWS_REGION
sleep 20
vpcid=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=${VPC_STACK_NAME}-VPC |jq -r  '.Vpcs[].VpcId')
Subnet01=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=${VPC_STACK_NAME}-Subnet01 |jq -r '.Subnets[].SubnetId')
Subnet02=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=${VPC_STACK_NAME}-Subnet02 |jq -r '.Subnets[].SubnetId')
Subnet03=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=${VPC_STACK_NAME}-Subnet03 |jq -r '.Subnets[].SubnetId')

# 建立 IAM Role: AmazonEKSAdminRole
aws iam create-role --role-name AmazonEKSAdminRole --assume-role-policy-document file://assume-role-policy.json
aws iam attach-role-policy --role-name AmazonEKSAdminRole --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam attach-role-policy --role-name AmazonEKSAdminRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam put-role-policy --role-name AmazonEKSAdminRole --policy-name EKSAdminExtraPolicies --policy-document file://eks-admin-iam-policy.json
aws iam put-role-policy --role-name GetRoleallow --policy-name GetRoleallow --policy-document file://getroleallow.json
sleep 5
iamrole=$(aws iam get-role --role-name AmazonEKSAdminRole --query 'Role.Arn' --output text)

# 新增建立ec2的key-pair 請妥善保管登入worker node 可以用
aws ec2 create-key-pair --key-name eksworkshop --query 'eksworkshop' --output text > $CURRENT_HOME/eksworkshop.pem
echo "建立 ec2的key-pair 用於 ssh 登入 worker node，保存於 $CURRENT_HOME/eksworkshop.pem"

echo "正在安裝 kubectl 指令..."
# 佈署 EKS
REGION=$AWS_REGION EKS_ADMIN_ROLE=$iamrole VPC_ID=$vpcid SUBNET1=$Subnet01 SUBNET2=$Subnet02 SUBNET3=$Subnet03 CLUSTER_STACK_NAME=$CLUSTER_STACK_NAME make create-eks-cluster
}

# 確認CloudFormation 狀態是否完成
checkeksstatus() {
while [ $(aws cloudformation describe-stacks --stack-name $CLUSTER_STACK_NAME |jq -r '.Stacks[].StackStatus') != 'CREATE_COMPLETE' ]
do
   sleep 10
done
}

# 新建ECR
createecr() {
# aws ecr create-repository --repository-name <名稱> --region $AWS_REGION
$(aws ecr get-login --no-include-email --region $AWS_REGION)
echo "ecr的 token 在 $CURRENT_HOME/.docker/config.json"
echo "上傳必要images 到ACR上"
 aws ecr create-repository --repository-name alertmanager --region $AWS_REGION > /dev/null 2>&1
 docker pull marketplace.gcr.io/google/prometheus/alertmanager:2.2 > /dev/null 2>&1
 docker tag  marketplace.gcr.io/google/prometheus/alertmanager:2.2 ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/alertmanager:2.2 > /dev/null 2>&1
 docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/alertmanager:2.2 > /dev/null 2>&1
 
 aws ecr create-repository --repository-name prometheus --region $AWS_REGION > /dev/null 2>&1
 docker pull marketplace.gcr.io/google/prometheus:2.2 > /dev/null 2>&1
 docker tag  marketplace.gcr.io/google/prometheus:2.2 ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/prometheus:2.2 > /dev/null 2>&1
 docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/prometheus:2.2 > /dev/null 2>&1
 
 aws ecr create-repository --repository-name nodeexporter --region $AWS_REGION > /dev/null 2>&1
 docker pull marketplace.gcr.io/google/prometheus/nodeexporter:2.2 > /dev/null 2>&1
 docker tag  marketplace.gcr.io/google/prometheus/nodeexporter:2.2 ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/nodeexporter:2.2 > /dev/null 2>&1
 docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/nodeexporter:2.2 > /dev/null 2>&1
 
 aws ecr create-repository --repository-name kubestatemetrics --region $AWS_REGION > /dev/null 2>&1
 docker pull marketplace.gcr.io/google/prometheus/kubestatemetrics:2.2 > /dev/null 2>&1
 docker tag  marketplace.gcr.io/google/prometheus/kubestatemetrics:2.2 ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/kubestatemetrics:2.2 > /dev/null 2>&1
 docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/kubestatemetrics:2.2 > /dev/null 2>&1
 
 aws ecr create-repository --repository-name grafana --region $AWS_REGION > /dev/null 2>&1
 docker pull marketplace.gcr.io/google/prometheus/grafana:2.2 > /dev/null 2>&1
 docker tag  marketplace.gcr.io/google/prometheus/grafana:2.2 ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/grafana:2.2 > /dev/null 2>&1
 docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/grafana:2.2 > /dev/null 2>&1
 
 aws ecr create-repository --repository-name debian9 --region $AWS_REGION > /dev/null 2>&1
 docker pull marketplace.gcr.io/google/prometheus/debian9:2.2 > /dev/null 2>&1
 docker tag  marketplace.gcr.io/google/prometheus/debian9:2.2 ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/debian9:2.2 > /dev/null 2>&1
 docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/debian9:2.2 > /dev/null 2>&1
 
}


# 安裝 kubectl 指令
installKubectl() {
  echo "正在安裝 kubectl 套件中..."
  printf "  安裝 kubectl 套件中......"
  apt-get -y install kubectl > /dev/null 2>&1 && echo "完成"
}

# 執行更新IAM role
updaterole(){
cd $CURRENT_HOME/eks-templates
sed -i "s/620154271401/${AWS_ACCOUNT_ID}/g" assume-role-policy.json
sed -i "s/harry-admin/${iamuseraccount}/g" assume-role-policy.json
aws iam update-assume-role-policy --role-name AmazonEKSAdminRole --policy-document file://assume-role-policy.json
}

createiamgroup(){
aws iam put-group-policy --group-name EKSAdmin --policy-document file://getroleallow.json --policy-name EKSAdmingrouprole
echo "記得將IAM user 加入倒 EKSAdmin群組, 然後每個人都要執行 updatekubectlconfigure()"
}

# 更新kubectl configure
updatekubectlconfigure() {
cd $CURRENT_HOME/eks-templates
# AmazonEKSAdminRole IAM Role
iamrole=$(aws iam get-role --role-name AmazonEKSAdminRole --query 'Role.Arn' --output text)
aws --region $AWS_REGION eks update-kubeconfig --name $CLUSTER_STACK_NAME --role-arn $iamrole
}


installkeycloak(){
helm install --name keycloak -f keycloak-values.yaml stable/keycloak
# keycloakpw=$(kubectl get secret --namespace default keycloak-http -o jsonpath="{.data.password}" | base64 --decode)
echo "安裝 keycloak，帳號為 admin  密碼為 systex "
}



installistio(){
# 建立istio 
echo "安裝istio 1.1.2"
ISTIO_VERSION=1.1.2 > /dev/null 2>&1
curl -sL "https://github.com/istio/istio/releases/download/$ISTIO_VERSION/istio-$ISTIO_VERSION-linux.tar.gz" | tar xz > /dev/null 2>&1

cd istio-$ISTIO_VERSION > /dev/null 2>&1
cp ./bin/istioctl /usr/local/bin/istioctl > /dev/null 2>&1
chmod +x /usr/local/bin/istioctl > /dev/null 2>&1
export PATH=$PATH:$HOME/istio-$ISTIO_VERSION/bin/ > /dev/null 2>&1


# tiller
kubectl apply -f install/kubernetes/helm/helm-service-account.yaml > /dev/null 2>&1
helm init --service-account tiller --node-selectors "beta.kubernetes.io/os"="linux"  > /dev/null 2>&1
sleep 10

## 安裝istio 加入其他工具
kubectl create namespace istio-system > /dev/null 2>&1 
sleep 1
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
  passphrase: c3lzdGV4
EOF

  helm template install/kubernetes/helm/istio-init --name istio-init --namespace istio-system | kubectl apply -f - > /dev/null 2>&1
  helm template install/kubernetes/helm/istio \
    --name istio --namespace istio-system \
    --set sidecarInjectorWebhook.enabled=true \
    --set pilot.traceSampling=1.0 \
    --set pilot.resources.requests.cpu=100m \
    --set pilot.resources.requests.memory=256Mi \
    --set grafana.enabled=true \
    --set tracing.enabled=true \
    --set servicegraph.enabled=true \
    --set kiali.enabled=true \
    --set kiali.createDemoSecret=true \
	--set gateways.istio-egressgateway.enabled=false \
	--set gateways.istio-ingressgateway.sds.enabled=true \
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


InstallEcrJenkins(){

# ECR & jenkins
 # 建立IAM User 
  aws iam create-user --user-name jenkine-ecr
  
  new_key=$(aws iam create-access-key --user-name jenkine-ecr  | jq -e -r .AccessKey)
  jenkine_ACCESS_KEY_ID=$(printf "%s" $new_key | jq -e -r .AccessKeyId)
  jenkine_SECRET_ACCESS_KEY=$(printf "%s" $new_key | jq -e -r .SecretAccessKey)
  jenkine_arn=$(aws iam get-user --user-name jenkine-ecr | jq  -r '.User[]'|grep arn)
  
cat <<'EOF' > jenkins-ecr-role-assume.json 
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "AllowPushPull",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "push-pull-user-1"
        ]
      },
      "Action": [
        "sts:AssumeRole"
      ]
    }
  ]
}
EOF


cat <<'EOF' > jenkins-ecr-role.json 
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "AllowPushPull",
      "Effect": "Allow",
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
	  "Resource":"*"
	}
  ]
}
EOF


sed -i "s@push-pull-user-1@${jenkine_arn}@g" jenkins-ecr-role-assume.json
#建立角色
aws iam create-role --role-name jenkins-ecr-assumerole --assume-role-policy-document file://jenkins-ecr-role-assume.json
#為角色建立內嵌許可政策
aws iam put-role-policy --role-name jenkins-ecr-assumerole --policy-name jenkins-ecr-role --policy-document file://jenkins-ecr-role.json


# https://github.com/awslabs/amazon-ecr-credential-helper
# 建立 configmap for awscredentials_jenkins 放在jenkins的 ~/.aws/credentials
echo "[default]" > awscredentials_jenkins
echo "aws_access_key_id = $jenkine_ACCESS_KEY_ID" >> awscredentials_jenkins
echo "aws_secret_access_key = $jenkine_SECRET_ACCESS_KEY" >> awscredentials_jenkins
# kubectl create configmap aws-iam-jenkine-ecr-key --from-file=awscredentials_jenkins  > /dev/null 2>&1


# 建立 configmap for awscredentials_jenkins 放在jenkins的 .docker/config.json
#  348053640110.dkr.ecr.us-west-2.amazonaws.com
cat <<'EOF' > docker-config.json
{
	"credHelpers": {
		"aws_account_id.dkr.ecr.region.amazonaws.com": "ecr-login"
	}
}
EOF

sed -i "s/region/${AWS_REGION}/g" docker-config.json
sed -i "s/aws_account_id/${AWS_ACCOUNT_ID}/g" docker-config.json
kubectl create configmap docker-registry-key --from-file=docker-config.json  > /dev/null 2>&1
# kubectl create configmap google-container-key  --from-file=docker-config.json  > /dev/null 2>&1


  echo "安裝 Jenkins ..."
  git clone https://github.com/harryliu123/devops-hands-on.git > /dev/null 2>&1
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
  printf "create repository..." && aws ecr create-repository --repository-name=jnlp-slave > /dev/null 2>&1
  printf "build..." && docker build --build-arg jenkine_ACCESS_KEY_ID=${jenkine_ACCESS_KEY_ID} jenkine_SECRET_ACCESS_KEY=${jenkine_SECRET_ACCESS_KEY} -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/jnlp-slave:v1 -f devops-hands-on/jenkins/slave/Dockerfileaws > /dev/null 2>&1
  printf "push..." && docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/jnlp-slave:v1 > /dev/null 2>&1
  echo "完成"

  printf "  正在安裝 jenkins:lts ..."
  helm install --name jenkins \
    --set cloud.provider.aws=true \
    --set Master.ServiceType=ClusterIP \
    --set Master.K8sAdminCredential=$K8S_ADMIN_CREDENTIAL \
    --set Agent.Image=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/jnlp-slave \
    --set Agent.ImageTag=v1 \
    --set Master.AdminPassword=systex \
    --set Master.AwsAccountId=${AWS_ACCOUNT_ID} \
    --set Master.AwsRegion=${AWS_REGION} \
    --set configmap.docker.config_json=docker-registry-key \
    devops-hands-on/jenkins > /dev/null 2>&1 && echo "完成"

}

installEFK() {
  cd $CURRENT_HOME

  echo "安裝 Elasticsearch + Fluentd + Kibana ..."
  printf "  安裝中 ..."
  kubectl apply -f devops-hands-on/logging-efk.yaml > /dev/null 2>&1 && echo "完成"

}

installKSM() {
  echo "安裝 Kube-state-metrics ..."
  printf "  安裝中 ..."
  kubectl apply -f devops-hands-on/kube-state-metrics/app-crd.yaml > /dev/null 2>&1 
  kubectl apply -f devops-hands-on/kube-state-metrics/prometheus-metrics_sa_manifest.yaml --namespace logging > /dev/null 2>&1 
  sed -i 's/prometheus:2.2/prometheus\/prometheus:2.2/g' devops-hands-on/kube-state-metrics/prometheus-metrics_manifest.yaml
  sed -i 's/marketplace.gcr.io\/google\/prometheus/Registryname/g' devops-hands-on/kube-state-metrics/prometheus-metrics_manifest.yaml
  sed -i "s@Registryname@${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com@g" devops-hands-on/kube-state-metrics/prometheus-metrics_manifest.yaml
  kubectl apply -f devops-hands-on/kube-state-metrics/prometheus-metrics_manifest.yaml --namespace logging  > /dev/null 2>&1 && echo "完成"
  
  # 讓 AKS 可以去ACR 拉images
  kubectl patch serviceaccount prometheus-metrics-alertmanager -n logging -p '{"imagePullSecrets": [{"name": "acr-auth"}]}'
  kubectl patch serviceaccount prometheus-metrics-grafana -n logging -p '{"imagePullSecrets": [{"name": "acr-auth"}]}'
  kubectl patch serviceaccount prometheus-metrics-kube-state-metrics -n logging -p '{"imagePullSecrets": [{"name": "acr-auth"}]}'
  kubectl patch serviceaccount prometheus-metrics-node-exporter  -n logging -p '{"imagePullSecrets": [{"name": "acr-auth"}]}'
  kubectl patch serviceaccount prometheus-metrics-prometheus -n logging -p '{"imagePullSecrets": [{"name": "acr-auth"}]}'
  kubectl patch serviceaccount default -n logging -p '{"imagePullSecrets": [{"name": "acr-auth"}]}'
  
  # 刪除因為還沒設定Secrets 的失敗 pod
  while [ `kubectl get po -n logging | grep prometheus-metrics-grafana | grep Running | grep '1/1' | wc -l` -eq 0 ]
  do
  sleep 5
  kubectl delete pod -n logging `kubectl get pods -n logging| awk '$3 == "Init:ImagePullBackOff" {print $1}'` > /dev/null 2>&1
  kubectl delete pod -n logging `kubectl get pods -n logging| awk '$3 == "ImagePullBackOff" {print $1}'` > /dev/null 2>&1
  kubectl delete pod -n logging `kubectl get pods -n logging| awk '$3 == "CrashLoopBackOff" {print $1}'` > /dev/null 2>&1
  done
}


setupService() {
  cd $CURRENT_HOME
  
  echo "設定對外服務項目..."
  
  printf "  等待對外IP配發中..."
  while [ `kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' | wc -c` -eq 0 ]
  do
    sleep 1
  done  
  INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' | nslookup | grep Address | tail -n1 | awk -F" " '{print $2}') 
  echo "(IP=$INGRESS_HOST)...完成"

  printf "  開啟對外服務中..."
  helm template --set istio.ingressgateway.ip=$INGRESS_HOST devops-hands-on/svc | kubectl apply -f - > /dev/null 2>&1 && echo "完成"
}

cd ~
CURRENT_HOME=$(pwd)

rm -rf ~/.my-env
rm -rf key.json

createhaproxy(){
cd $CURRENT_HOME/eks-templates
ingressgateway=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.EXTERNAL-IP[0].ip}')
sed -i "s/ingressgateway/${ingressgateway}/g" Haproxy-create.yaml
aws cloudformation create-stack  --stack-name  Haproxy-create --template-body file://Haproxy-create.yaml --region $AWS_REGION
sleep 20
}
#######################################################

main
