#!/usr/bin/env bash
###########
# 安裝 Lab 課程環境
###

# 設定參數
initParameter() {
  echo "參數設定確認中..."
  # GOOGLE_PROJECT_ID
  if [ -z $GOOGLE_PROJECT_ID  ]; then
    GOOGLE_PROJECT_ID=systex-lab-$(cat /proc/sys/kernel/random/uuid | cut -b -6)
    echo "  未定義 GOOGLE_PROJECT_ID. 由系統自動產生...(GOOGLE_PROJECT_ID=$GOOGLE_PROJECT_ID)" 
  fi
  
  # GOOGLE_ZONE
  if [ -z $GOOGLE_ZONE  ]; then
    GOOGLE_ZONE=asia-east1-a
    echo "  未定義 GOOGLE_ZONE.       由預設使用台灣...(GOOGLE_ZONE=$GOOGLE_ZONE)"
  fi
}

# 建立全新的 GCP Project 
createProject() {
  echo "正在設定專案中..."
  # 建立 GCP PROJECT ID
  printf "  建立專案($GOOGLE_PROJECT_ID)......"
  gcloud projects create $GOOGLE_PROJECT_ID > /dev/null 2>&1 && echo "完成"

  # 切換 gcloud 至新建的 Project Id
  gcloud config set project $GOOGLE_PROJECT_ID

  # find billing account 
  GOOGLE_BILLING_ACCOUNT=$(gcloud beta billing accounts list | grep True | awk -F" " '{print $1}')

  # link to GCP billing account 
  printf "  設定帳戶帳單連結...."
  gcloud beta billing projects link $GOOGLE_PROJECT_ID --billing-account $GOOGLE_BILLING_ACCOUNT > /dev/null 2>&1 && echo "完成"
}



initParameter
createProject
cat <<EOF
GOOGLE_PROJECT_ID=$GOOGLE_PROJECT_ID
GOOGLE_ZONE=$GOOGLE_ZONE
EOF
