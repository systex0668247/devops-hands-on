#!/usr/bin/env bash
###########
# 安裝 Lab(k8s) 課程環境
###########

#!/usr/bin/env bash
###########
# 專案 AWS 建立 EKS & keycloak
###########


###################
## 必要變數輸入 ###
###################

AWS_REGION=<輸入要在哪個region建立>              # us-west-2
AWS_ACCOUT_ID=<輸入自己的accout_id>              # 348053640110
iamuseraccount=<請變更自己的AWS上的IAM user>     # A



CURRENT_HOME=$(pwd)
rm -rf ~/.my-env
rm -rf key.json
rm -rf devops-hands-on

git clone https://github.com/abola/devops-hands-on.git

##########################
### 執行的function
##########################
initialclientcloudshell
installeks
checkeksstatus
createecr
installKubectl
updaterole
updatekubectlconfigure
createiamgroup
createhaproxy


> ~/.my-env
echo "GOOGLE_PROJECT_ID=$GOOGLE_PROJECT_ID" >> ~/.my-env
echo "GOOGLE_ZONE=$GOOGLE_ZONE" >> ~/.my-env
echo "GOOGLE_GKE_NAME=$GOOGLE_GKE_NAME" >> ~/.my-env
echo "INGRESS_HOST=$INGRESS_HOST" >> ~/.my-env
echo "KeycloakPW=$keycloakpw" >> ~/.my-env
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
Keycloak               : http://keycloak.$INGRESS_HOST.nip.io/    $keycloakpw
-------------------------------------------------------------
EOF






initialclientcloudshell(){
# 安裝aws cli on GCP上的 cloudshell
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
sleep 20
vpcid=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=${VPC_STACK_NAME}-VPC |jq -r  '.Vpcs[].VpcId')
Subnet01=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=${VPC_STACK_NAME}-Subnet01 |jq -r '.Subnets[].SubnetId')
Subnet02=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=${VPC_STACK_NAME}-Subnet02 |jq -r '.Subnets[].SubnetId')
Subnet03=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=${VPC_STACK_NAME}-Subnet03 |jq -r '.Subnets[].SubnetId')

# AmazonEKSAdminRole IAM Role
aws iam create-role --role-name AmazonEKSAdminRole --assume-role-policy-document file://assume-role-policy.json
aws iam attach-role-policy --role-name AmazonEKSAdminRole --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam attach-role-policy --role-name AmazonEKSAdminRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam put-role-policy --role-name AmazonEKSAdminRole --policy-name EKSAdminExtraPolicies --policy-document file://eks-admin-iam-policy.json
aws iam put-role-policy --role-name GetRoleallow --policy-name GetRoleallow --policy-document file://getroleallow.json
iamrole=$(aws iam get-role --role-name AmazonEKSAdminRole --query 'Role.Arn' --output text)

# 新增建立ec2的key-pair 請妥善保管登入worker node 可以用
aws ec2 create-key-pair --key-name eksworkshop --query 'eksworkshop' --output text > $CURRENT_HOME/eksworkshop.pem

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
sed -i "s/620154271401/${AWS_ACCOUT_ID}/g" assume-role-policy.json
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
aws --region $AWS_REGION eks update-kubeconfig --name eksdemo --role-arn $iamrole
}



installkeycloak(){
helm install --name keycloak -f keycloak-values.yaml stable/keycloak
# keycloakpw=$(kubectl get secret --namespace default keycloak-http -o jsonpath="{.data.password}" | base64 --decode)
echo "帳號為 admin  密碼為 systex "
}


createhaproxy(){
ingressgateway=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.EXTERNAL-IP[0].ip})
sed -i "s/ingressgateway/${ingressgateway}/g" Haproxy-create.yaml
aws cloudformation create-stack  --stack-name  Haproxy-create --template-body file://Haproxy-create.yaml --region $AWS_REGION
sleep 20
}

