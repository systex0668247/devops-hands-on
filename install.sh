#!/usr/bin/env bash
###########
# 安裝 Lab 課程環境
###

# static parameter list 
DEFAULT_SERVICE_ACCOUNT="Compute Engine default service account"

# 設定參數
initParameter() {
  echo "參數設定確認中..."
  # GOOGLE_PROJECT_ID
  if [ -z $GOOGLE_PROJECT_ID  ]; then
    GOOGLE_PROJECT_ID=systex-lab-$(cat /proc/sys/kernel/random/uuid | cut -b -6)
    echo "  未定義 GOOGLE_PROJECT_ID.   由系統自動產生...(GOOGLE_PROJECT_ID=$GOOGLE_PROJECT_ID)" 
  fi
  
  # GOOGLE_ZONE
  if [ -z $GOOGLE_ZONE  ]; then
    GOOGLE_ZONE=asia-east1-a
    echo "  未定義 GOOGLE_ZONE.         使用預設值.......(GOOGLE_ZONE=$GOOGLE_ZONE)"
  fi
  
  # GOOGLE_GCE_NAME
  if [ -z $GOOGLE_GCE_NAME  ]; then
    GOOGLE_GCE_NAME=devops-hands-on
    echo "  未定義 GOOGLE_GCE_NAME.     使用預設值.......(GOOGLE_GCE_NAME=$GOOGLE_GCE_NAME)"
  fi

  # GOOGLE_GCE_MACHINE
  if [ -z $GOOGLE_GCE_MACHINE  ]; then
    GOOGLE_GCE_MACHINE=n1-standard-1
    echo "  未定義 GOOGLE_GCE_MACHINE.  使用預設值.......(GOOGLE_GCE_MACHINE=$GOOGLE_GCE_MACHINE)"
  fi

  # GOOGLE_GCE_IMAGE
  if [ -z $GOOGLE_GCE_IMAGE  ]; then
    GOOGLE_GCE_IMAGE=centos-7
    echo "  未定義 GOOGLE_GCE_IMAGE.    使用預設值.......(GOOGLE_GCE_IMAGE=$GOOGLE_GCE_IMAGE)"
  fi

  read -p "確認開始安裝(Y/n)?" yn
  case $yn in
      [Nn]* ) echo "動作取消 "; exit;;
  esac  
}

# 建立全新的 GCP Project 
createProject() {
  echo "正在設定專案中..."
  # 建立 GCP PROJECT ID
  printf "  建立專案($GOOGLE_PROJECT_ID)......"
  gcloud projects create $GOOGLE_PROJECT_ID > /dev/null 2>&1 && echo "完成"

  # 切換 gcloud 至新建的 Project Id
  printf "  切換至專案($GOOGLE_PROJECT_ID)..."
  gcloud config set project $GOOGLE_PROJECT_ID > /dev/null 2>&1 && echo "完成"

  # find billing account 
  GOOGLE_BILLING_ACCOUNT=$(gcloud beta billing accounts list | grep True | awk -F" " '{print $1}')

  # link to GCP billing account 
  printf "  設定帳戶帳單連結...."
  gcloud beta billing projects link $GOOGLE_PROJECT_ID --billing-account $GOOGLE_BILLING_ACCOUNT > /dev/null 2>&1 && echo "完成"
}

createComputeEngine() {
  echo "正在建立VM..."
  
  printf "  啟用 Compute Engine API..."
  gcloud services enable compute.googleapis.com > /dev/null 2>&1 && echo "完成"
  
  printf "  尋找預設的Compute Engine服務帳戶..."
  GOOGLE_COMPUTE_SERVICE_ACCOUNT=$(gcloud iam service-accounts list | grep "$DEFAULT_SERVICE_ACCOUNT" | awk -F" " '{print $6}')
  echo "($GOOGLE_COMPUTE_SERVICE_ACCOUNT)"

  printf "  尋找映像檔($GOOGLE_GCE_IMAGE)專案路徑..."
  GOOGLE_GCE_IMAGES_LIST=$(gcloud compute images list | grep "${GOOGLE_GCE_IMAGE}" | awk -F" " '{print $1 "," $2}')
  GOOGLE_GCE_IMAGE=$(echo ${GOOGLE_GCE_IMAGES_LIST} | awk -F"," '{print $1}')
  GOOGLE_GCE_IMAGE_PROJECT=$(echo ${GOOGLE_GCE_IMAGES_LIST} | awk -F"," '{print $2}')
  echo "($GOOGLE_GCE_IMAGE_PROJECT/$GOOGLE_GCE_IMAGE)"

  printf "  開始建立VM($GOOGLE_GCE_NAME)..."
  gcloud compute --project=$GOOGLE_PROJECT_ID \
    instances create $GOOGLE_GCE_NAME \
    --zone=$GOOGLE_ZONE \
    --machine-type=$GOOGLE_GCE_MACHINE \
    --subnet=default \
    --network-tier=PREMIUM \
    --maintenance-policy=MIGRATE \
    --service-account=$GOOGLE_COMPUTE_SERVICE_ACCOUNT \
    --image=$GOOGLE_GCE_IMAGE \
    --image-project=$GOOGLE_GCE_IMAGE_PROJECT \
    --boot-disk-size=10GB \
    --boot-disk-type=pd-standard \
    --boot-disk-device-name=GCE-$GOOGLE_GCE_NAME \
    --tags=http-server,https-server \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
    > /dev/null 2>&1 && \
    echo "完成"
    
  printf "  設定firewall(80/443)..."  
  gcloud compute --project=$GOOGLE_PROJECT_ID firewall-rules create default-allow-http --direction=INGRESS --priority=1000 --network=default --action=ALLOW --rules=tcp:80 --source-ranges=0.0.0.0/0 --target-tags=http-server > /dev/null 2>&1 && \
  gcloud compute --project=$GOOGLE_PROJECT_ID firewall-rules create default-allow-https --direction=INGRESS --priority=1000 --network=default --action=ALLOW --rules=tcp:443 --source-ranges=0.0.0.0/0 --target-tags=https-server > /dev/null 2>&1 && \
  echo "完成"

}

initParameter
createProject
createComputeEngine
cat <<EOF
GOOGLE_PROJECT_ID=$GOOGLE_PROJECT_ID
GOOGLE_ZONE=$GOOGLE_ZONE
EOF
