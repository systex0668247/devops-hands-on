# DevOps Lab

---

## 章節目標 

* 認識 Jenkins 
* Pipeline-as-Code
* DevOps lifecycle 

---

# Task 0: 確認你的需求環境

### 設定您的 kubernetes 

```bash=
bash <(curl -L https:// )
```

---

# Task 1: 在 Kubernetes 快速安裝 Jenkins

Jenkins 是目前最被廣泛使用的 CI/CD 工具，但在容器議題下，Jenkins 的安裝與設定，衍生出許多複雜的問題，例如 Docker-in-Docker(DinD)、Docker outside-of Docker (DooD)、整合k8s等等；但這些議題的處理已超出課程範圍。

本階段你將會使用 Helm，安裝客製化版本的 Jenkins，此版本已解決課程中會接遭遇的問題，不建議直接用於生產環境下，但內部評估與測試，可幫助你省下許多時間。

---

## Helm

![helm logo](https://github.com/helm/helm/raw/master/docs/logos/helm_logo_transparent.png "helm" =250x)

Helm是Kubernetes的一個套件管理工具，用來簡化Kubernetes應用的部署和管理。可以把Helm比作CentOS的yum工具。Helm由兩部分組成，客户端helm和服務端tiller。

---

### 安裝客戶端 Helm


#### 安裝 Helm 官方預先編譯版本的執行檔

```bash=
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get | bash
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

## Task 2: 建立與設定 Pipeline 專案

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
https://github.com/abola/aaa
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
https://github.com/<your_github_account>/devops-hands-up.git
```

接著點擊左下角 `Generate Pipeline Script` 您會在下方的文字框中得到相對應的 pipeline 指令 

請拷貝文字框中的指令後，返回專案設定頁面

---

接著請將拷貝的指令貼上 Pipeline Script 中的文字框，並將拉取 git 的過程設定為一個關卡 _(stage)_ ，參考以下內容，編輯您的 Pipeline Script


```pipeline=
node {
    stage('init'){
        git 'https://github.com/<your_github_account>/devops-hands-on.git'
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

## Task 3: Pipeline as Code

本階段我們將試著將 Pipeline code 移轉至專案中，並讓 Jenkins 偵測 SCM 的變更。最終 Jenkins 會在原始碼變更後，依照專案中定義的 __Jenkinsfile__ 執行工作。

---

### Create DevOps Style Project

在前一個 Task 我們在 Jenkins 中完成了第一個 Pipeline 專案。但真實的環境中，開發者(dev)是無法操作正式環境的CI/CD工具，慣例上，我們會將 Pipeline 的代碼，與專案的原始碼放在一起，如下所示

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

#### 

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

### 移轉 Pipeline 至原始碼

1. 請另開新視窗，至 GitHub 網站並開啟您的專案，網址參考以下，並更換為您的帳號
```
https://github.com/<your_github_account>/devops-lab-sample
```

2. 切換至目錄 `sample/pipeline-as-code` 下，您現在的畫面應該類似下圖 
![Pipeline check](https://github.com/abola/devops-hands-on/raw/master/images/devops-github-pac.png) 

3. 點擊畫面上方偏右的按鍵 `Create new file`
4. 在接下來的畫面中，請將檔名命名為 `Jenkinsfile` 
5. 將先前設定於 Jenkins 中的 Pipeline code 貼上，您可以參考以下內容，同樣請記得更換 __<your_github_account>__
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
現在您的畫面應該類似下圖
![GitHub-Jenkinsfile](https://github.com/abola/devops-hands-on/raw/master/images/devops-github-jenkinsfile.png)
6. 切換至頁面的最下方，點擊 `Commit new file` 存檔
7. 返回 Jenkins 視窗，在頁面的左側![Configure](https://github.com/abola/devops-hands-on/raw/master/images/devops-configure.png =135x)進入專案設定畫面
8. 勾選`Poll SCM`(或中文`輪詢 SCM`)，並在 `Schedule`文字輸入框中輸入 `* * * * *` 代表每分鐘都會詢問 SCM，但只有在有變更時，才會觸發建置，完成設定如下圖
![Poll-SCM](https://github.com/abola/devops-hands-on/raw/master/images/devops-poll-scm.png)
9. 接著再至頁面下方 Pipeline 區塊，變更下拉功能`Definition` 至 `Pipeline script from SCM`
10. 子項目 `SCM` 的下拉選單由 `None` 變更為 `Git`
11. `SCM` 子項目 `Repository URL` 請輸入以下網址，請記得更換 __`<your_github_account>`__
```
https://github.com/<your_github_account>/devops-lab-sample.git
```
11. `Script Path` 項目，請輸入 `sample/pipeline-as-code/Jenkinsfile`，指向先前建立的 `Jenkinsfile` 的相對路徑
12. 確認您的設定畫面如下圖
![Configure](https://github.com/abola/devops-hands-on/raw/master/images/devops-config-pac.png)
13. 按下方 `Save` 儲存設定後離開

---

### 測試自動化建置

現在要返回您的 GitHub 頁面，修改 HelloWorld.java  以觸發 Jenkins 作業完成本階段作業 

1. 開啟以下網址，同樣請記得更換 __<your_github_account>__
```
https://github.com/<your_github_account>/devops-lab-sample/tree/master/sample/pipeline-as-code/src/main/java/com/systex
```
2. 點擊 HelloWorld.java 
3. 點擊畫面右側功能，編輯檔案
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
6. 返回 Jenkins 靜候約一分鐘內，建置會自行啟動，並完成所有 Pipeline 中定義的工作。



---

## Task 4: DevOps style project (K8S)

---


## DevOps & Infra as code Part1. 

## DevOps & Infra as code Part2. 

# Monitoring

離開Jenkins

<pre>
└── <span style="color:red;font-weight: bold;">kubernetes/</span>
└── <span style="color:blue">src/</span>
    └── <span style="color:blue">java/com/systex/</span>
        └── HelloWorld.java   
    └── <span style="color:blue">resources/</span>
└── Dockerfile
└── Jenkinsfile
└── pom.xml
</pre>



#### Python Project style

<pre>
└── <span style="color:red;font-weight: bold;">kubernetes/</span>
    └── deployment.yaml
    └── service.yaml
└── <span style="color:blue;">src/</span>
    └── Hello.py
└── Dockerfile</span>
└── <span style="color:red;font-weight: bold;">Jenkinsfile</span>
└── requirements.txt
└── <span style="color:red;font-weight: bold;">README.md</span>
</pre>

基本上 Source Code Repository 中所有的內容都是由 Developer 所提供的，在良好的開發/合作慣例下，一定要在專案根目錄中提供 `README.md` 說明專案的內容資訊等等。

`kubernetes/` 目錄內包含所有 kubernetes 的設定資訊(option)


以上專案架構上的建構，實際如何應用設置，當然可以不同，但仍強烈建議將協作方式明確記載在 `README.md` 檔案中 (或 `CONTRIBUTING.md`)

為專案提供 pipeline 
