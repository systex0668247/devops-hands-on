# CI/CD Lab

CI/CD tool 是 DevOps 精神實現中很重要的環境，在本lab中，你會從一步一步簡單的使用 Jenkins，到使用 Pipeline as Code，最終實現 Infrastructure as Code 與 DevOps 精神，讓開發與維運團隊流暢的分工協作。

---

## 章節目標 

* Task 1: 在 Kubernetes 快速安裝 Jenkins
* Task 2: 建立與設定 Pipeline 專案
* Task 3: Pipeline as Code
* Task 4: Infrastructure as Code (Iac)

---

# Task 0: 確認你的需求環境

### 設定您的 kubernetes 

```bash=
bash <(curl -L http://tiny.cc/systex-devops01-k8s)
```

---

# Task 1: 在 Kubernetes 快速安裝 Jenkins

Jenkins 是目前最被廣泛使用的 CI/CD 工具，為何選擇 Jenkins 我們已在課程中介紹

接著我們會在 kubernetes 下使用套件工具 Helm，安裝客製化版本的 Jenkins，此版本專門設計用於本課程使用，不建議直接用於生產環境下，但用於內部評估、測試或客製開發參考，可幫助你省下許多時間。


---

## Helm

![helm logo](https://github.com/helm/helm/raw/master/docs/logos/helm_logo_transparent.png "helm" =250x)

Helm是Kubernetes的一個套件管理工具，用來簡化Kubernetes應用的部署和管理。可以把Helm比作CentOS的yum工具。Helm由兩部分組成，客户端helm和服務端tiller。

---

### 安裝客戶端 Helm


#### 安裝 Helm 官方預先編譯版本的執行檔

```bash=
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get | DESIRED_VERSION=v2.13.1 bash
helm init
```

安裝完成後，你應可以看到最後的 Happy Helming

<pre>
Tiller (the Helm server-side component) has been installed into your Kubernetes Cluster.

Please note: by default, Tiller is deployed with an insecure 'allow unauthenticated users' policy.
To prevent this, run `helm init` with the --tiller-tls-verify flag.
For more information on securing your installation see: https://docs.helm.sh/using_helm/#securing-your-helm-installation
<span style="color:red">Happy Helming!</span>
</pre>

查詢 Helm client/server 版本，確認安裝完成

```bash=
helm version
```

你應該要有類似以下的輸出結果

```
Client: &version.Version{SemVer:"v2.13.1", GitCommit:"618447cbf203d147601b4b9bd7f8c37a5d39fbb4", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.13.1", GitCommit:"618447cbf203d147601b4b9bd7f8c37a5d39fbb4", GitTreeState:"clean"}
```

---
### 設定 Tiller 權限

Tiller 是 Helm 安裝在 Kubernetes cluster 中的服務，前一步我們呼叫 `helm init` 其實就是在安裝 Tiller 服務。Helm 這麼方便的原因，主要就是因為 Tiller 常駐在 Kubernetes cluster 中，方便 Helm client 透過 Tiller 來操作 Kubernetes。我們需要建立一組服務帳戶，並授予管理員角色，才能讓 Tiller 在 Kubernetes cluster 中運作。

#### 建立 Tiller 服務帳戶與授權 

```bash=
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
```
---

## Jenkins 權限設定

為了練習方便，我們會將授與 Jenkin 擁有 Kubernetes `cluster-admin` 的權限。

#### 建立服務帳戶 `jenkins-deployer` 並授權
```bash=
kubectl create sa jenkins-deployer
kubectl create clusterrolebinding jenkins-deployer-role --clusterrole=cluster-admin --serviceaccount=default:jenkins-deployer
K8S_ADMIN_CREDENTIAL=$(kubectl describe secret jenkins-deployer | grep token: | awk -F" " '{print $2}')
```

```bash=
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
```
---

## 安裝客製版本 Jenkins


#### 下載客製化版本設定
```bash=
cd ~
git clone https://github.com/bryanwu66/devops-hands-on.git
cd devops-hands-on/
```

#### 使用 `helm install` 指令安裝

`helm install` 會依照目錄 `jenkins/` 內的設定，安裝指定的應用，參考[HELM INSTALL](https://helm.sh/docs/helm/#helm-install "helm install")

```bash=
helm install jenkins/ \
  --name jenkins \
  --set Master.K8sAdminCredential=$K8S_ADMIN_CREDENTIAL 
```

---

### 靜候啟動

輸入以下指令，靜候服務啟動

```bash=
watch kubectl get po 
```

直到畫面狀態類似下方結果後，再往下進行，確認你的 READY 與 STATUS 分別為 `1/1`  及 `Running` 為止，輸入 `Ctrl+C` 離開

```
NAME                      READY   STATUS    RESTARTS   AGE
jenkins-56bbc5578-qkxlw   1/1     Running   0          1m
```

---

### 取得入口ip

使用以下指令，找到 jenkins 對外服務的 ip-address
```bash=
kubectl get svc
```

你會看到接近如下的結果，`EXTERNAL-IP` 欄位就是對外服務的 ip-address

```
NAME            TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)        AGE
jenkins         LoadBalancer   10.55.252.39    35.185.128.186   80:30997/TCP   4m
jenkins-agent   ClusterIP      10.55.255.201   <none>           50000/TCP      4m
kubernetes      ClusterIP      10.55.240.1     <none>           443/TCP        2h
```

---

### 確認 Jenkins 安裝完成

打開你的瀏覽器，並貼上對外服務的 ip-address，你應該會看到登入畫面如下圖

![LoginPage](https://github.com/abola/devops-hands-on/raw/master/images/devops-loginpage.png =300x)

帳號/密碼為 `admin/password` 順利登入後，如果您如下畫面，您以完成本階段作業

![Mainpage](https://github.com/abola/devops-hands-on/raw/master/images/devops-mainpage.png)

---

# Task 2: 建立與設定 Pipeline 專案

本階段，我們要試著建立並運行一些簡單的 pipeline，階段目標理解簡單的 pipeline 用法，以及使用 pipeline 抓取 git 的原始碼。

登入您的 Jenkins ，並確認您所在的頁面如下圖所示 _(依照您電腦的語言可能略有不同)_，如果不在此頁面中，您可點擊左上角 `Jenkins 頭像` 即可。

![Mainpage](https://github.com/abola/devops-hands-on/raw/master/images/devops-mainpage.png)

---

接著請點擊左上角 ![New Item](https://github.com/abola/devops-hands-on/raw/master/images/devops-new-item.png =150x)

在接下來的畫面中，請輸入您的專案名稱為 `my-pipeline`，並在下選專案的類別選擇 `Pipeline`，在畫面的最下方，點擊 `OK` 進入下一步

![Pipeline Project](https://github.com/abola/devops-hands-on/raw/master/images/devops-pipeline-project.png)

---

在Jenkins專案第一次建立的時候，會直接進入設定畫面，您可以簡單的檢視畫面上所有可用的功能，而且每個功能的右方都會有一個 ![說明](https://github.com/abola/devops-hands-on/raw/master/images/devops-question-mark.png =35x)，單點擊後會顯示功能詳盡的說明，若您是第一次使用 Jenkins，非常建議您將每一個![說明](https://github.com/abola/devops-hands-on/raw/master/images/devops-question-mark.png =35x)快速檢視一遍。

在畫面的最後，您應該會看到 `Pipeline` 的大項目，並伴隨著一個名稱為`Script`的文字輸入框，你會看到右側有個下拉選單，名稱應該為 `try sample pipeline...`，請點擊後，選擇 `Hello World`，如下圖

![HelloWorld](https://github.com/abola/devops-hands-on/raw/master/images/devops-hello-world.png)

完成後，您會有一個非常簡易的 pipeline script 片段，如果沒有，您也可以直接拷貝以下片段，貼在 `Script` 文字輸入框中

```pipeline=
node {
   echo 'Hello World'
}
```

請點擊畫面下方 `Save` 完成設定

---

接著您會停留在 Jenkins 專案的頁面中，左側的選項是專案的功能列表

* ![Configure](https://github.com/abola/devops-hands-on/raw/master/images/devops-configure.png =135x) 返回設定頁面調整設定
* ![Build Now](https://github.com/abola/devops-hands-on/raw/master/images/devops-build-now.png =135x) 立即啟動專案建置

現在我們要進行第一次的建置，請點擊 ![Build Now](https://github.com/abola/devops-hands-on/raw/master/images/devops-build-now.png =135x)

不久之後，在您畫面的左下方`Build History` 區塊，應該會出現 `#1 `的作業開始運行，如下圖

![Build Now](https://github.com/abola/devops-hands-on/raw/master/images/devops-build-history.png)

`Build History` 區塊會顯示正在進行中，或近期的建置過的記錄清單，同時您可以點擊進入觀察其過程。

請點擊 `#1` 進入觀查作業

---

進入作業內容的畫面後，左側功能列會變更為作業操作的功能列，通常我們只會用到 ![Console Output](https://github.com/abola/devops-hands-on/raw/master/images/devops-console-output.png =200x) 

請點擊左側 `Console Output` 

---

此頁面在作業完成前，都會不斷的自動更新，直到作業完成或被中止。您最終完成的輸出結果會類似下方

<pre>
Started by user admin
Running in Durability level: MAX_SURVIVABILITY
[Pipeline] Start of Pipeline
[Pipeline] node
Still waiting to schedule task
Waiting for next available executor
Agent default-kp348 is provisioned from template Kubernetes Pod Template
Agent specification [Kubernetes Pod Template] (jenkins-jenkins-slave ): 
* [jnlp] gcr.io/my-jenkins-20190320/jnlp-slave-docker-k8s:latest(resourceRequestCpu: 200m, resourceRequestMemory: 256Mi, resourceLimitCpu: 200m, resourceLimitMemory: 256Mi)
* [docker] docker:dind

Running on default-kp348 in /home/jenkins/workspace/my-pipeline
[Pipeline] {
[Pipeline] echo
Hello World
[Pipeline] }
[Pipeline] // node
[Pipeline] End of Pipeline
<span style="color:red">Finished: SUCCESS</span>
</pre>

在作業的最未輸出，會顯示作業的狀態，以此為例，我們的作業狀態是 `SUCCESS` ，表示我們已經完成了第一個 pipeline 作業。

---

接下來要更深入一點點使用 pipeline，我們要使用 pipeline 至您 GitHub 的 Repository 中抓取原始碼。

在開始前，您必需在 GitHub 中建立一組資源，請 ___另開一個新的瀏覽器視窗___ 進入 [GitHub, https://github.com](https://github.com) 網站並登入 

登入後，再輸入以下網址

```
https://github.com/abola/devops-lab-sample
```

這個專案內容是 Lab 過程中練習用的原始碼，請點擊畫面右上角的 ![Fork](https://github.com/abola/devops-hands-on/raw/master/images/devops-fork.png =100x) ，這動作類似於將原始碼拷貝一份至您個人的 Git Repository 中，然後你可以對原始碼進行修改。

---

請返回 Jenkins 的視窗，照以下步驟操作

1. 請點擊畫面左上角 ![Back-to-Project](https://github.com/abola/devops-hands-on/raw/master/images/devops-back-project.png =150x) 返回專案設定。
2. 接著點擊畫面左側 ![Configure](https://github.com/abola/devops-hands-on/raw/master/images/devops-configure.png =135x) 返回設定頁面
3. 在設定畫面持續下拉，直到看見 `Pipeline` 設定區塊
4. 在`Pipeline`區塊的左下角，有一個連節 `Pipeline Syntax`請點擊，將會另開新視窗如下圖，進入下一步

![Pipeline Syntex](https://github.com/abola/devops-hands-on/raw/master/images/devops-pipeline-syntex.png)

---

這個頁面會協助您，將一些基本及常見的功能，轉換為pipeline script。以目前目標為例，我們希望至 git 中取得原始碼，請在 `Steps > Sample Step` 中選擇 `git: Git`

接著下方會更新，出現文字輸入框，請在 `Repository URL` 項目中，輸入您的 GitHub 資源位置，這是先前我們 `Fork` 項目的資源位置，輸出的結果應該要如下方

```
https://github.com/<your_github_account>/devops-lab-sample.git
```

接著點擊左下角 `Generate Pipeline Script` 您會在下方的文字框中得到相對應的 pipeline 指令 

請拷貝文字框中的指令後，返回專案設定頁面

---

接著請將拷貝的指令貼上 Pipeline Script 中的文字框，並將拉取 git 的過程設定為一個關卡 _(stage)_ ，參考以下內容，編輯您的 Pipeline Script


```pipeline=
node {
    stage('init'){
        git 'https://github.com/<your_github_account>/devops-lab-sample.git'
    }
    stage('exec'){
        sh 'cat README.md'
    }
}
```

設定完成後，請按最下的 `Save` 儲存離開設定頁面

---

接著再次點擊左側 ![Build Now](https://github.com/abola/devops-hands-on/raw/master/images/devops-build-now.png =135x) 

這次不用進入 `Build History` 中觀察作業的狀態，靜候片刻，您的畫面會出現類似下圖所示

![Pipeline Stages](https://github.com/abola/devops-hands-on/raw/master/images/devops-stages.png)

定義關卡後，我們可以在專案的頁面中，直接查看每一個關卡的執行過程與記錄，非常方便。

到此，您已完成了 Task 2.

---

# Task 3: Pipeline as Code

本階段我們將試著將 Pipeline code 移轉至專案中，並讓 Jenkins 偵測 SCM 的變更。最終 Jenkins 會在原始碼變更後，依照專案中定義的 __Jenkinsfile__ 執行工作。

---

## DevOps 風格專案設計模式

在前一個 Task 我們在 Jenkins 中完成了第一個 Pipeline 專案。但真實的環境中，開發團隊無權限操作正式環境的CI/CD工具。慣例上，Pipeline 的代碼主要由開發團隊設計提供，並與專案的原始碼放在一起 _(如下方所示)_ ，之後由維運團隊運行、微調、反饋，達成符合DevOps精神的協作模式。

#### Java project style sample

<pre>
└── <span style="color:blue">src/</span>
    └── <span style="color:blue">main/java/com/systex/</span>
        └── HelloWorld.java   
└── <span style="color:red;font-weight: bold;">Jenkinsfile</span>
└── pom.xml
└── README.md
</pre>

* __`Jenkinsfile`__ 依照專案慣用的 CI/CD 工具，將 CI/CD pipeline 資訊放在專案的根目錄中是開發慣例(Best practice)。因為我們用的是 Jenkins Pipeline 所以檔案為 __`Jenkinsfile`__。其它常見的如 TravisCI的 `.travis.yml `.

* __`README.md`__ 在良好的開發/合作慣例下，一定要在專案根目錄中提供 __`README.md`__ 說明專案的內容資訊等等。

---

### 設計並建立Pipeline


1. 請返回 Jenkins 主頁面，如果您忘 Jenkins 入口位置，請返回 Task 1: [取得入口ip](#取得入口ip) 依指示查找。

2. 請點擊左上角 ![New Item](https://github.com/abola/devops-hands-on/raw/master/images/devops-new-item.png =150x) 建立新的專案

3. 在接下來的畫面中，請輸入您的專案名稱為 `pipeline-as-code`，並在下選專案的類別選擇 `Pipeline`，在畫面的最下方，點擊 `OK` 進入下一步

4. 在頁面的最下方，`Pipeline > Script` 項目的文字輸入框中輸入以下內容

```pipeline=
node {
    stage('init'){
        git 'https://github.com/<your_github_account>/devops-lab-sample.git'
    }
    stage('build'){
        sh 'cd sample/pipeline-as-code && mvn package'
    }
    stage('exec'){
        sh 'cd sample/pipeline-as-code && java -cp target/hello-1.0.jar com.systex.HelloWorld'
    }
}
```

簡單解釋 Pipeline 中執行的內容 

* `stage('init')` 會去您的 GitHub 抓取原始碼，請記得修改 __<your_github_account>__ 成為您的 GitHub 帳號
* `stage('build')` 會切換至專案目錄中，依照 `pom.xml` 的內容打包 Java 專案
* `stage('exec')` 執行編譯後的結果，最終應該會顯示 Hello World!.

5. 請按畫面最下方 `Save` 儲存

---

### 測試 Pipeline 

1. 接著您會在專案的畫面中，請點擊左側 ![Build Now](https://github.com/abola/devops-hands-on/raw/master/images/devops-build-now.png =135x) 
靜候專案建置完成，如果您的三個關卡(stage)都正常完成，如下圖
![Pipeline check](https://github.com/abola/devops-hands-on/raw/master/images/devops-pipeline-check.png) 

表示您的 pipeline code 無誤，接著我們可以移轉至原始碼。

---

### 移轉Pipeline至原始碼

1. 請另開新視窗，至 GitHub 網站並開啟您的專案，網址參考以下，並更換為您的帳號
```
https://github.com/<your_github_account>/devops-lab-sample
```

2. 切換至目錄 `sample/pipeline-as-code` 下，您現在的畫面應該類似下圖 
![Pipeline check](https://github.com/abola/devops-hands-on/raw/master/images/devops-github-pac.png) 

3. 點擊畫面上方偏右的按鍵 `Create new file`
4. 在接下來的畫面中，請將檔名命名為 `Jenkinsfile` 
5. 將先前設定於 Jenkins 中的 Pipeline code 貼上，並更換 `stage('init')` 的內容，完整內容如下
```pipeline=
node {
    stage('init'){
        checkout scm
    }
    stage('build'){
        sh 'cd sample/pipeline-as-code && mvn package'
    }
    stage('exec'){
        sh 'cd sample/pipeline-as-code && java -cp target/hello-1.0.jar com.systex.HelloWorld'
    }
}
```

__`checkout scm`__ 是指由 CI 工具中所定義的 Source Code 存放位置中，直接取得原始碼，這樣子我們就不需在代碼中，將原始碼的位置變成 __hard code__

現在您的畫面應該類似下圖
![GitHub-Jenkinsfile](https://github.com/abola/devops-hands-on/raw/master/images/devops-github-jenkinsfile.png)

6. 切換至頁面的最下方，點擊 `Commit new file` 存檔

---

### 自動化建置

1. 返回 Jenkins 視窗，在頁面的左側![Configure](https://github.com/abola/devops-hands-on/raw/master/images/devops-configure.png =135x)進入專案設定畫面
2. 勾選`Poll SCM`(或中文`輪詢 SCM`)，並在 `Schedule`文字輸入框中輸入 `* * * * *` 代表每分鐘都會詢問 SCM，但只有在有變更時，才會觸發建置，完成設定如下圖
![Poll-SCM](https://github.com/abola/devops-hands-on/raw/master/images/devops-poll-scm.png)
3. 接著再至頁面下方 Pipeline 區塊，變更下拉功能`Definition` 至 `Pipeline script from SCM`
4. 子項目 `SCM` 的下拉選單由 `None` 變更為 `Git`
5. `SCM` 子項目 `Repository URL` 請輸入以下網址，請記得更換 __`<your_github_account>`__
```
https://github.com/<your_github_account>/devops-lab-sample.git
```
6. `Script Path` 項目，請輸入 `sample/pipeline-as-code/Jenkinsfile`，指向先前建立的 `Jenkinsfile` 的相對路徑
7. 確認您的設定畫面如下圖
![Configure](https://github.com/abola/devops-hands-on/raw/master/images/devops-config-pac.png)
8. 按下方 `Save` 儲存設定後離開

---

### 測試自動化建置

現在要返回您的 GitHub 頁面，修改 HelloWorld.java  以觸發 Jenkins 作業完成本階段作業 

1. 在其它視窗中，開啟以下網址，同樣請記得更換 __<your_github_account>__
```
https://github.com/<your_github_account>/devops-lab-sample/tree/master/sample/pipeline-as-code/src/main/java/com/systex
```
2. 點擊 HelloWorld.java 
3. 點擊畫面右側功能，編輯檔案(如下圖)
![Configure](https://github.com/abola/devops-hands-on/raw/master/images/devops-github-edit.png =300x)
4. 隨意修改Hello World! 輸出內容，參考如下
```java=
package com.systex;

public class HelloWorld {
    public static void main(String[] args) {
        System.out.println("Hello World! Hello World!");
    }
}
```
5. 修改後，點擊畫面最下方 `Commit Changes` 儲存
6. 返回 Jenkins 畫面，靜候約一分鐘內，建置會自行啟動，並完成所有 Pipeline 中定義的工作。最終確認建置的結果是否與您的修改相同(如下圖示)
![Configure](https://github.com/abola/devops-hands-on/raw/master/images/devops-task3-final.png)

恭喜您已經完成了本階段的練習

---

# Task 4: Infrastructure as Code (Iac)

本階段，我們會以一個簡單的專案示例，展示Developer 與 Operator 如何在 IaC 的架構下，如何協同合作

---

## 示例內容說明

本包示例是由一個前端(由python編寫)組件與兩個後端(由java及php編寫)組成。前端組件會向後端發起請求，後端則會回應自身所在容器的 hostname。

### 示例檔案結構
<pre>
./sample/iac
└── <span style="color:blue;">backend-java/</span>
└── <span style="color:blue;">backend-php/</span>
└── <span style="color:blue;">frontend-python/</span>
└── <span style="color:blue;">helm/</span>
└── Jenkinsfile
</pre>

* __`helm`__ 內存放 kubernetes 的 `YAML` 樣版資料，協助我們以參數的方式定義 `YAML` 的內容
* __`Jenkinsfile`__ 定義了 Pipeline 運作的內容

---

### Pipeline 內容說明
開啟先前您 Fork 的 GitHub 專案，在路徑 `sample/iac` 下，找到並點擊檔案 `Jenkinsfile` 進入檢視內容，或 <a href="https://github.com/abola/devops-lab-sample/blob/master/sample/iac/Jenkinsfile" target="_blank">點此處開啟</a>


這個專案定義的 `Jenkinsfile` 分為四大區塊

#### `parameters{...}`

我們將所有建置過程中，有可能的變數提出成為參數(ex: 版本/憑證)。通常我們會將有權限的內容，例如憑證，定義為參數，讓維運團隊可自行更換內容。

#### `stage('init'){...}`

將完整的代碼由 SCM 中取回，後續CI/CD所執行的內容，皆定義在本包代碼中(IaC)。這內容我們已在前一個 Task 進行過 

#### `stage('ci'){...}`

此區塊定義了原始碼如何組合成 Docker Image 的過程，我們明確定義出流程，使用 CI 工具協助完成自動化

#### `stage('cd'){...}`

此區塊使用工具 `helm` 佈署 kubernetes 相關的作業，例如 Deployment/Service。此區塊是為輔助維運團隊操作而設計的，但內容仍然是由開發團隊所提供。

---

## 開發團隊 CI 作業

以下動作模擬開發團隊操作情境

1. __返回 Jenkins 首頁__
如果您不記得 Jenkins 的網址，請至 Google Cloud Shell 中輸入下方指令， `EXTERNAL IP`欄位下的 IP 即為您 Jenkins 的入口
    ```bash=
    kubectl get svc 
    ```

2. __建立新作業__
    * 請點擊畫面左上角的 ![New Item](https://github.com/abola/devops-hands-on/raw/master/images/devops-new-item.png =150x)
    * 並於次畫面中，將作業取名為 `IaC-CI` 
    * 作業類型選 `Pipeline` 
    * 接著在最下方點擊 `OK`

3. __設定作業內容__ 
下拉畫面直到Pipeline 區塊
    * 在 `Definition` 項目中選擇 `Pipeline script from SCM` 
    * 在 `SCM` 選 `Git`，`Repository URL` 參考以下網址，修改github帳號，成為您自己的帳號名稱
        ```
        https://github.com/<YOUR_ACCOUNT>/devops-lab-sample.git
        ``` 
    * 指定 `Script Path` 欄位內容為 `sample/iac/Jenkinsfile`
    * 點擊最下方 `Save` 儲存設定

4. __第一次建置__ 
在 Jenkinsfile 中，使用 `parameters{...}` 設定的參數，都會自動帶入 Jenkins 中成為設定值，但最少必需執行一次，否則 Jenkins 不會知道遠端 Jenkinsfile 中的內容。
    * 點擊左側![Build Now](https://github.com/abola/devops-hands-on/raw/master/images/devops-build-now.png =135x)
    * 第一次建置結果會錯誤是正常的沒關係，請重新整理頁面
    * 現在您左側建置選項，會變成 `Build with Parameters` 請點擊後進入下一步

5. __`Build with Parameters`__ 
在此示例中，因為我們定義了五個參數，所以在開始建置前，畫面會出現提示，您可以在此頁面，調整參數的內容
    * __googleProjectId__ 是您的 GCP 專案名稱，請在 Google Cloud Shell 中輸入以下指令找到您的專案名稱
        ```bash=
        gcloud projects list
        ```
    * __gcrCredentials__ 是您的 Google Container Registry(GCR) 的憑證資料，CI執行的過程中，會將 docker 打包後的映像檔上傳至此，您可以使用以下指令，取得一個臨時的 token，此token期效僅有不到一個小時，在 Google Cloud Shell 中輸入以下指令，並將結果拷貝貼回此欄位
        ```bash=
        gcloud auth print-access-token
        ```
    * __buildTag__ 是手動指定映像檔的版號，在本示例中，不論您設定值為何，最終都會為結果打上 `latest` 版號
    * __backendJavaReplicas__ 與 __backendPhpReplicas__ 是設計給予維運團隊操作使用，在 CI 階段，這兩個設定值不會有效果。
    * __stage__ 設定執行範圍，目前是模擬開發團隊 CI  作業，請選擇 `CI`。
    * 點擊最下方 `BUILD` 開始建置

6. __確認完成__
    * 靜候建置完成，過程大約2分鐘，這段時間您可以點擊畫面中 Pipeline 圖形，即可觀察 LOG 
    * 建置完成後，為了確認 CI 結果，我們要確認 Google Container Registry(GCR) 中是否有成功上傳，輸入以下指令查看 `backend-java` 服務的映像檔，請將第一行指令中的 `<YOUR_PROJECT_ID>` 更換為您的 GCP 專案名稱
        ```bash=
        GOOGLE_PROJECT_ID=<YOUR_PROJECT_ID>
        gcloud container images list-tags gcr.io/${GOOGLE_PROJECT_ID}/backend-java --project=${GOOGLE_PROJECT_ID}
        ```
    * 完成後，您看到的結果應該會類似下方
        ```
        DIGEST        TAGS        TIMESTAMP
        152ac1f875ee  1.0,latest  2019-04-19T11:06:02
        ```

---

## 維運團隊 CD 作業

我們會另外建立一個作業項目，模擬維運團隊作業操作過程，因為作業的內容都已定義在代碼中，所以除了作業的名稱外，其餘設定都相同

1. __建立新作業__
    * 請點擊畫面左上角的 ![New Item](https://github.com/abola/devops-hands-on/raw/master/images/devops-new-item.png =150x)
    * 並於次畫面中，將作業取名為 `IaC-CD` 
    * 作業類型選擇最下方的 `Copy from` 並在文字輸入框中指定拷貝的來源為 `IaC-CI`
    * 接著在最下方點擊 `OK`
2. __設定作業內容__ 
    * 進入設定畫面後，您會發現所有的設定皆已完成，請下拉至最下方，點擊 `Save` 
    
3. __`Build with Parameters`__ 
與先前不同的是，這次您的畫面直接就看的到選項`Build with Parameters`

    * 點擊左側 `Build with Parameters`
    * __googleProjectId__ 是您的 GCP 專案名稱，請在 Google Cloud Shell 中輸入以下指令找到您的專案名稱
        ```bash=
        gcloud projects list
        ```
    * __gcrCredentials__ 與 __buildTag__ 選項在 CD 過程中不會使用，無需修改
    * __backendJavaReplicas__ 與 __backendPhpReplicas__ 指定後端服務所開啟的 `replica` 數量，開發團隊會給予建議值的設定，目前是 `2`，我們先使用預設值執行建置。
    * __stage__ 設定執行範圍，目前是模擬維運團隊 CD  作業，<span style="color: red;font-weight:bold;">請選擇 `CD`</span>。
    * 點擊最下方 `BUILD` 開始建置
4. __觀察服務狀態__
在建置完成後， Jenkins 會控制您的 kubernetes cluster，部署示例的服務映像檔
    * 開啟您的 Google Cloud Shell 輸入以下指令觀察 kubernetes cluster pods 的狀態，請保持開啟不要關閉
        ```bash=
        watch -n1 kubectl get pods
        ```
    * 在 Jenkins IaC-CD 作業建置完成後，很快的，您應該會在 Google Cloud Shell中看到以下畫面，其中 `backend-java`與`backend-php`都啟動了兩個 PODs
```
NAME                              READY     STATUS    RESTARTS   AGE
backend-java-666bbdd89f-49qh5     1/1       Running   0          14s
backend-java-666bbdd89f-d2kwp     1/1       Running   0          14s
backend-php-6786656664-qbqts      1/1       Running   0          14s
backend-php-6786656664-whkkp      1/1       Running   0          14s
frontend-python-c5dd559b8-vsj56   1/1       Running   0          14s
jenkins-794699fc6d-j94bh          1/1       Running   0          1d
```

5. __調整負載參數__
最後，我們要模擬維運團隊調整服務負載量的操作

    * 重覆上方步驟 `3. Build with Parameters`的過程，這次我們將 __backendJavaReplicas__ 與 __backendPhpReplicas__ 分別調整為 `3` 與 `1`
    * 點擊最下方 `BUILD` 開始建置
    * 接著開啟您的 Google Cloud Shell 觀察 Pods 的狀態，在建置完成後，您會發現服務很快的就轉換完成，`backend-java`增加為三個，而`backend-php`減少為一個

```

NAME                              READY     STATUS    RESTARTS   AGE
backend-java-666bbdd89f-49qh5     1/1       Running   0          8m
backend-java-666bbdd89f-6rxns     1/1       Running   0          1m 
backend-java-666bbdd89f-d2kwp     1/1       Running   0          8m
backend-php-6786656664-qbqts      1/1       Running   0          8m
frontend-python-c5dd559b8-vsj56   1/1       Running   0          8m
jenkins-794699fc6d-j94bh          1/1       Running   0          1d
```

---

您已完成本階段所有的 Lab ，在這過程中，您學習了如何一步一步的從簡單的使用 Jenkins，到使用 Pipeline as Code，最終實現 Infrastructure as Code 與 DevOps 精神，讓開發與維運團隊流暢的分工協作。

# Clean

當您已經完成 Lab 後，建議您刪除已建立的 Lab 環境，以節省您的費用

輸入以下指令清除 Lab

```bash=
gcloud projects delete $GOOGLE_PROJECT_ID
```
