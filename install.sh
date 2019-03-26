#!/usr/bin/env bash
###########
# 安裝 Lab 課程環境
###


# 建立獨立的 GCP Project 
createProject() {
  # 建立 GCP PROJECT ID
  gcloud projects create $GOOGLE_PROJECT_ID

  # 切換 gcloud 至新建的 Project Id
  gcloud config set project $GOOGLE_PROJECT_ID

  # find billing account 
  GOOGLE_BILLING_ACCOUNT=$(gcloud beta billing accounts list | grep True | awk -F" " '{print $1}')

  # link to GCP billing account 
  gcloud beta billing projects link $GOOGLE_PROJECT_ID --billing-account $GOOGLE_BILLING_ACCOUNT
}

#Stop execution on any error
trap "fail_trap" EXIT
set -e

# Parsing input arguments (if any)
export INPUT_ARGUMENTS="${@}"
#set -u

set +u

if [ -z $GOOGLE_PROJECT_ID  ]; then
  echo "未定義 GOOGLE_PROJECT_ID. 由系統自動產生."
  GOOGLE_PROJECT_ID=systex-lab-$(cat /proc/sys/kernel/random/uuid | cut -b -6)
fi

createProject
