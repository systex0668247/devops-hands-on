# Docker for Beginners - Linux

在本實驗中，我們將介紹一些基本的Docker命令和一個簡單的構建運行工作流程。我們首先運行一些簡單的容器，然後我們將使用Dockerfile來構建自定義應用程序。最後，我們將看看如何使用綁定掛載修改正在運行的容器，如果您正在使用Docker進行積極開發的話。

## Tasks：

* Task 0：環境建置
* Task 1：運行一些簡單的Docker容器
* Task 2：使用Docker打包並運行自定義應用程序
* Task 3：修改正在運行的網站

> 請盡可能自行輸入指令，增加印象

## Task 0：環境建置

您將需要以下所有內容完成，才能順利進行

### 建立雲端虛擬機

如果您尚未建立雲端虛擬機，

* Google Cloud Platform

    登入 GCP 在 Google Cloud Shell 下輸入以下指令

```
bash <(curl -L http://tiny.cc/systex-devops01-install)
```

### 從 GitHub clone Lab 原始碼

使用以下命令從GitHub clone Lab的原始碼。這將在一個名為的新子目錄中復制實驗室的repo linux_tweet_app。

```
cd ~
git clone http://tiny.cc/systex-devops01-lab
```

---

## Task1：運行一些簡單的Docker容器

有不同的方法來使用容器。這些包括：

運行單個任務：這可以是shell腳本或自定義應用程序。
交互式：這將您連接到容器，類似於SSH到遠程服務器的方式。
在後台：對於長期運行的服務，如網站和數據庫。
在本節中，您將嘗試其中的每個選項，並了解Docker如何管理工作負載。

---

## 在Alpine Linux容器中運行單個任務

在這一步中，我們將啟動一個新容器並告訴它執行`hostname`指令。容器將啟動，執行`hostname`指令，然後退出。

在Linux console中執行以下指令。

```
docker run alpine hostname
```

第一次執行時，會無法在本地端找到 `alpine:lastest` 映像檔。發生這種情況時， Docker 會自動至 Docker Hub 找尋，並拉回(`pull`)映像檔。

拉回映像檔後，會顯示容器內的 `hostname` (如下示例中的 `888e89a3b36b`)

```
 Unable to find image 'alpine:latest' locally
 latest: Pulling from library/alpine
 88286f41530e: Pull complete
 Digest: sha256:f006ecbb824d87947d0b51ab8488634bf69fe4094959d935c0c103f4820a417d
 Status: Downloaded newer image for alpine:latest
 888e89a3b36b
```
只要在容器內啟動的程序(process)仍在運行，Docker就會使容器保持運行。
在本例案中，`hostname` 是我們啟動的程序，當顯示輸出完成後便結束；這意味著容器也會跟著停止。
但是 Docker 預設情況下並不會刪除容器的資源，你可以觀察到容器仍然存在，但狀態顯示為 `Exited`

列出所有容器。

```
docker container ls --all
```

請注意您的alpine 容器目前處於該`Exited`狀態。

```
 CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS            PORTS               NAMES
 888e89a3b36b        alpine              "hostname"          50 seconds ago      Exited (0) 49 seconds ago                       awesome_elion
```

---

## 課堂練習-01

執行以下指令，可以列出您目前本地端 repo 的所有映像檔

```
docker images
```

您的畫面輸出應該會類似以下所示

```
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
mysql               latest              7bb2586065cd        28 hours ago        477MB
ubuntu              latest              94e814e2efa8        2 weeks ago         88.9MB
alpine              latest              5cb3aa00f899        2 weeks ago         5.53MB
```

* 要如何刪除本地端 repo 的映像檔？

> 提示：請試著看 docker help

---
