# Docker for Beginners - Linux

在本實驗中，我們將先介紹一些基本的Docker命令。首先運行一些簡單的容器，然後我們將使用Dockerfile來構建自定義應用程式。最後，我們將自定義的映像檔，上傳至Google Container Repository中。

---

## Tasks：

* Task 0：環境建置
* Task 1：運行一些簡單的Docker容器
* Task 2：構建一個簡單的 Hello World 網站映像檔
* Task 3：更多 Dockerfile 常用指令練習

> 請盡可能自行輸入指令，增加印象

---

## Task 0：環境建置

您將需要以下所有內容完成，才能順利進行

### 建立雲端虛擬機

如果您尚未建立雲端虛擬機

* Google Cloud Platform

    登入 GCP 在 Google Cloud Shell 下輸入以下指令，約需 3min

```
bash <(curl -L http://tiny.cc/systex-devops01-install)
```

    完成後，請依照指示登入虛擬機，並換為 root user，後續示例皆以 root 設計

```
sudo su 
```

### 安裝 Docker

在您首次登入虛擬機，或尚未安裝 Docker 請依照以下指示執行

拷貝以下指令，貼上虛擬機命令列上執行 

```
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io
systemctl start docker
```

為確認是否安裝完成，執行hello-world

```
docker run hello-world
```

### 從 GitHub clone Lab 原始碼

拷貝以下命令從GitHub clone Lab的原始碼。

```
cd ~
git clone https://github.com/bryanwu66/devops-hands-on.git
```

若您以上指令無法正確執行，請先確認是否已安裝 `git`

```
yum install -y git
```

---

## Task1：運行一些簡單的Docker容器

有不同的方法來使用容器。這些包括：

`SingleTask`：這可以是shell腳本或自定義應用程序。
`Interactively`：這將您連接到容器，類似於SSH到遠程服務器的方式。
`Background`：對於長期運行的服務，如網站和數據庫。

在本節中，您將嘗試其中的每個選項，並了解Docker如何管理工作負載。

---

## 在Alpine Linux容器中運行 SingleTask 容器 

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
docker ps --all
```

請注意您的alpine 容器目前處於該`Exited`狀態。

```
 CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS            PORTS               NAMES
 888e89a3b36b        alpine              "hostname"          50 seconds ago      Exited (0) 49 seconds ago                       awesome_elion
```

`SingleTask`模式的容器非常好用，您可以構建一個映像檔，執行腳本配置某些內容 ___(例如Java的mvn、python的pip等等)___ 。之後任何人都可以執行容器(`docker run`)來執行該任務，他們不會碰到任何腳本配置或環境的問題。

---

## 在 Ubuntu 容器運行 Interactively 容器 ##

您可以使用 Docker 運行不同版本 Linux，例如在下方示例中，我們將在CentOS Linux 主機上運行Ubuntu Linux容器

運行Docker容器並訪問其shell。

```
docker run --interactive --tty --rm ubuntu bash
```

在這個例子中，我們給Docker三個參數：

* `--interactive` 指定使用互動式的 session。
* `--tty` 分配一個偽tty。
* `--rm` 告訴Docker在完成執行後，移除容器。

前兩個參數允許您與Docker容器進行互動，我們還告訴容器以`bash`作為主要 process（PID 1）。當容器啟動時，您將使用bash shell進入容器內 

在容器中執行以下指令。

`ls /` 將列出容器中根目錄的內容，`ps aux`將顯示容器中正在運行的 process，`cat /etc/issue`將顯示容器正在運行的Linux版本，在本示例中為 `Ubuntu 18.04.2 LTS`

```
ls /
```

```
ps aux
```

```
cat /etc/issue
```

輸入 `exit` 退出 shell。這將終止bash process，導致容器退出 (`Exited`)。

```
exit
```

這時您可以再執行一次 `docker ps --all` 您會發現看不到Ubuntu容器。因為參數 `--rm` 會在容器退出時，同時執行刪除。

為了好玩，我們來檢查VM主機的版本。

```
cat /etc/issue
```

你應該看到：

```
\S
Kernel \r on an \m
```

請注意，我們的VM主機正在運作的是 CentOS Linux，但我們能夠運行不同發行版本的 Ubuntu 容器。

但是，Linux容器需要Docker主機運行Linux內核。例如，Linux容器無法直接在Windows主機上運行。Windows容器也是如此，它們需要在具有Windows內核的Docker主機上運行。

當您將自己的圖像放在一起時，交互式容器非常有用。您可以運行容器並驗證部署應用程序所需的所有步驟，並在Dockerfile中捕獲它們。

你可以 提交一個容器來製作一個圖像 - 但是你應該盡可能地避免使用它。使用可重複的Dockerfile來構建圖像要好得多。你很快就會看到。

---

## 運行後台MySQL容器

後台容器是您運行大多數應用程序的方式。這是一個使用MySQL的簡單示例。

使用以下命令運行新的MySQL容器。

```
docker run \
  --detach \
  --name mydb \
  -e MYSQL_ROOT_PASSWORD=my-secret-pw \
  mysql:latest
```

`--detach` 將在後台運行容器。
`--name` 將它命名為mydb。
`-e` 將使用環境變量來指定root密碼

由於MySQL映像在本地端不存在，Docker會自動至Docker Hub中拉取映像檔。運行的過程會類似下方

```
 Unable to find image 'mysql:latest' locallylatest: Pulling from library/mysql
 aa18ad1a0d33: Pull complete
 fdb8d83dece3: Pull complete
 75b6ce7b50d3: Pull complete
 ed1d0a3a64e4: Pull complete
 8eb36a82c85b: Pull complete
 41be6f1a1c40: Pull complete
 0e1b414eac71: Pull complete
 914c28654a91: Pull complete
 587693eb988c: Pull complete
 b183c3585729: Pull complete
 315e21657aa4: Pull complete
 Digest: sha256:0dc3dacb751ef46a6647234abdec2d47400f0dfbe77ab490b02bffdae57846ed
 Status: Downloaded newer image for mysql:latest
 41d6157c9f7d1529a6c922acb8167ca66f167119df0fe3d86964db6c0d7ba4e0
```

只要MySQL正在運行，Docker就會讓容器在後台運行。

列出正在 __運行中__ 的容器。

```
docker ps
```

請注意您的容器正在運行

```
 CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS            NAMES
 3f4e8da0caf7        mysql:latest        "docker-entrypoint..."   52 seconds ago      Up 51 seconds       3306/tcp            mydb
```

您可以使用幾個內建的Docker命令來檢查容器中發生的事情：`docker logs`和`docker top`。

```
docker logs mydb
```

這顯示了來自MySQL Docker容器的日誌。

```
Initializing database
2019-03-28T08:14:49.127365Z 0 [Warning] [MY-011070] [Server] 'Disabling symbolic links using --skip-symbolic-links (or equivalent) is the default. Consider not using this option as it' is deprecated and will be removed in a future release.
2019-03-28T08:14:49.127466Z 0 [System] [MY-013169] [Server] /usr/sbin/mysqld (mysqld 8.0.15) initializing of server in progress as process 27
```

讓我們看一下容器內運行的 process。

```
docker top mydb
```

您應該看到MySQL程序（mysqld）正在容器中運行。

```
UID                 PID                 PPID                C                   STIME               TTY                 TIME                CMD
polkitd             4434                4418                1                   08:14               ?                   00:00:01            mysqld
```

雖然MySQL正在運行，但它在容器中是隔離的，因為沒有指定輸出的網絡端口。除非明確發布端口，否則網絡流量無法從主機到達容器。這在後續的項目中會進行。

使用列出MySQL版本docker container exec。

`docker exec`允許您在容器內執行指令。在這個例子中，我們將使用`docker exec`執行`mysql --user=root --password=$MYSQL_ROOT_PASSWORD --versionMySQL`容器內部的命令行等效命令。

```
docker exec -it mydb \
mysql --user=root --password=$MYSQL_ROOT_PASSWORD --version
```

您將看到MySQL版本號，以警告。

```
mysql: [Warning] Using a password on the command line interface can be insecure.
mysql  Ver 8.0.15 for Linux on x86_64 (MySQL Community Server - GPL)
```

您還可以使用`docker exec`連接到運行中的容器內執行 shell 。執行以下命令將為`sh`您提供MySQL容器內的交互式shell（）。

```
docker exec -it mydb sh
```

請注意，您的shell提示已更改。這是因為您的shell現在已連接到`sh`容器內。

讓我們通過再次運行相同的命令來檢查版本號，只是這次是在容器中的shell session中。

```
mysql --user=root --password=$MYSQL_ROOT_PASSWORD --version
```

輸出會與先前的相同

鍵入`exit`以退出交互式shell會話。

```
exit
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

* __問題：__ 要如何刪除本地端 repo 的映像檔？

> 提示：請試著看 docker help

---

## Task 2: 構建一個簡單的 Hello World 網站映像檔

在接下來兩個Task中，您將學習如何使用 Dockerfile 將自己的應用程序打包為 Docker 映像檔。

Dockerfile語法很簡單。在這項任務中，我們將從Dockerfile創建一個簡單的 python 網頁站台

## 建立 Dockerfile

讓我們看一下我們將要使用的Dockerfile，它構建了一個允許您發送推文的簡單網站。

1. 請確認您在正在的目錄中

```
cd ~/devops-hands-on/sample/hello
```

2. 顯示Dockerfile的內容

```
cat Dockerfile
```

```
 FROM python:alpine
 COPY . /app
 WORKDIR /app
 RUN pip install -r requirements.txt
 ENTRYPOINT ["python"]
 CMD ["app.py"]
```

讓我們看看Dockerfile中的每一行是做什麼的。

  * `FROM` 指定要用作您正在創建的新映像檔的來源映像。本示例中，我們使用的是 `python:alpine`。
  * `COPY` 將文件從Docker主機複製到已知位置的映像中。在此示例中，COPY用於將目錄 `~/devops-hands-on/sample/hello` 下的所有檔案，拷貝一份至映像中，映像檔內路徑為 `/app`
  * `WORKDIR` 指令用於設置Dockerfile中的`RUN`、`CMD`和`ENTRYPOINT`指令的工作錄(預設為 `/` )，該指令在Dockerfile文件中可以出現多次。
  * `RUN` 指令會執行指定的命令，本示例會在 `WORKDIR` 中找尋檔案 `requirements.txt` 依內容安裝 python 套件
  * `ENTRYPOINT` 指定從映像啟動容器時要運行的命令，如果有多個 `ENTRYPOINT` 指令，那只有最後一個生效；通常用來設置不會變化的指令，例如啟動服務 (mysqld)。本示例中為呼叫 `python` 
  * `CMD` 指定從映像啟動容器時要運行的命令。如果有多個 `CMD` 指令，那只有最後一個生效；通常用來設置參數類的項目。本示例中是將檔案 `app.py` 作為參數送入 `python` 命令執行

`ENTRYPOINT` 與 `CMD` 之間的差異比較難理解，但可運作的 `Dockerfile` 最少需要設置一個 `ENTRYPOINT` 或 `CMD` 。此項目我們會在下一個 Task 中進行。

## 建立映像檔

使用 `docker build` 命令，依照 `Dockerfile` 中的指令，建立新的Docker映像檔。

  * `-t` 允許我們為映像檔提供自定義名稱。
  * `.` 告訴 Docker 使用當前目錄

  __請務必在命令末尾包含句點 `.`__

```
docker build -t myapp:v1 .
```

下面輸出的是 `docker build` 的過程，仔細觀察， Dockerfile 中有幾個指令，過程中就會有多少 `Step`

```
Sending build context to Docker daemon   5.12kB
Step 1/6 : FROM python:alpine
 ---> a93594ce93e7
Step 2/6 : COPY . /app
 ---> 81dba3fb41bd
Step 3/6 : WORKDIR /app
 ---> Running in c76b3d70a1fb
Removing intermediate container c76b3d70a1fb
 ---> e619e172e462
Step 4/6 : RUN pip install -r requirements.txt
 ---> Running in 278eaa81cb6a
Removing intermediate container 278eaa81cb6a
 ---> bb386e897fe3
Step 5/6 : ENTRYPOINT ["python"]
 ---> Running in 8c43740a9ad5
Removing intermediate container 8c43740a9ad5
 ---> bf2c1328976f
Step 6/6 : CMD ["app.py"]
 ---> Running in bee171a4b18a
Removing intermediate container bee171a4b18a
 ---> 1b357fd7120f
Successfully built 1b357fd7120f
Successfully tagged myapp:v1
```

我們要試試看，如果相同的指令，再度執行一次會發生什麼情況

```
docker build -t myapp:v1 .
```

仔細觀察輸出內容，這次的結果會相當快速完成

```
Sending build context to Docker daemon   5.12kB
Step 1/6 : FROM python:alpine
 ---> a93594ce93e7
Step 2/6 : COPY . /app
 ---> Using cache
 ---> 81dba3fb41bd
Step 3/6 : WORKDIR /app
 ---> Using cache
 ---> e619e172e462
Step 4/6 : RUN pip install -r requirements.txt
 ---> Using cache
 ---> bb386e897fe3
Step 5/6 : ENTRYPOINT ["python"]
 ---> Using cache
 ---> bf2c1328976f
Step 6/6 : CMD ["app.py"]
 ---> Using cache
 ---> 1b357fd7120f
Successfully built 1b357fd7120f
Successfully tagged myapp:v1
```

你會發現大多的項目都出現了 `---> Using cache`，如果你的 Dockerfile 並沒有修改，前一次進行的動作就會被快取

輸入以下指令，確認本地端 repository 狀況

```
docker images
```

你會看到剛剛所建立的 `myapp:v1` 已經在本地端 repository 內了 

```
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
myapp               v1                  8023671c6799        15 seconds ago      101MB
```

## 運行映像檔

使用 `docker run` 命令，運行您創建的映像檔啟動新容器。

```
docker run -d -p 5000:5000 myapp:v1
```

簡單的說明一下指令參數的作用
  `-d` 在背景模式下運行此容器
  `-p 5000:5000` 將容器內的通訊埠5000(右側)，發佈到主機上的通訊埠5000(左側)

接著你可以使用 `docker ps` 指令觀察運行中的容器狀態，為了測試服務運作是否正常，輸入以下指令

```
curl localhost:5000
```

你的畫面應該要看到輸出結果如下 

```
Hello World!!!
```

如果看到 Hello World，恭喜你已成功的建立第一個容器服務。

---

## 課堂練習-02

現在你有一個容器正在運行中，你可以用 `docker ps` 來找尋運行中的容器清單，類似下方輸出結果。目前你應該有一個容器正在運行中

```
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS                    NAMES
b8375e3ded63        f97dc95a465e        "python app.py"     2 hours ago         Up 2 hours          0.0.0.0:5000->5000/tcp   optimistic_wu
```

* __問題：__ 要如何中止容器？

> 提示：請試著看 docker help

---

## Task 3: 更多 Dockerfile 常用指令練習

這個 Task 的內容，我們將不斷的練習重新改造 Dockerfile，檢視各個重要基礎指令的使用方式

在開始之前，以下內容都會在 Linux 命令列上進行檔案的編修，如果您並不熟悉 Linux shell 指令操作，強烈建議您先閱讀[鳥哥的Linux > vim 程式編輯器](http://linux.vbird.org/linux_basic/0310vi.php#vi_ex)

## EXPOSE

`EXPOSE` 指令，會宣告你的容器對外有那些通訊埠開啟，但此設定並不會對外服務，你還是要透過 `docker run -p` 的方式才能讓容器的通訊埠對外發佈服務

修改您的 Dockerfile 

```
vi Dockerfile
```

增加 EXPOSE 宣告，我們宣告開啟 `EXPOSE 5000`，加入Dockerfile 位置參考如下，並記得存檔再離開

```
FROM python:alpine

COPY . /app
WORKDIR /app

RUN pip install -r requirements.txt

EXPOSE 5000

ENTRYPOINT ["python"]
CMD ["app.py"]
```

完成後，我們要將修改的內容重新建立，並更換版本代碼至 `v2`

```
docker build -t myapp:v2 . 
```

現在我們可以同時啟動兩個不同版本的 `myapp` 比較差異

```
docker run -d myapp:v1
docker run -d myapp:v2 
```

你可以發現 `v2` 版本有宣告 `EXPOSE` 較 `v1` 多了  `5000/tcp` 的內容，但此時兩個容器都無法對外提供服務

```
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
45ff6b03b162        myapp:v2            "python app.py"     4 seconds ago       Up 3 seconds        5000/tcp            competent_dubinsky
af5ea393185c        myapp:v1            "python app.py"     6 seconds ago       Up 5 seconds                            blissful_gauss
```

使用 `EXPOSE` 指令，可指令 `docker run` 可搭配 `-P` 使用，Docker 主機會隨機分配對外通信埠與容器所宣告的對外埠連接 

```
docker run -d -P myapp:v2
```

觀察 `docker ps` 現在我們有三個容器運行中，其中有一個容器有連接對外服務 `0.0.0.0:32769`

```
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS                     NAMES
72346620f65c        myapp:v2            "python app.py"     3 seconds ago       Up 1 second         0.0.0.0:32769->5000/tcp   boring_austin
45ff6b03b162        myapp:v2            "python app.py"     5 minutes ago       Up 5 minutes        5000/tcp                  competent_dubinsky
af5ea393185c        myapp:v1            "python app.py"     5 minutes ago       Up 5 minutes                                  blissful_gauss
```

簡易測試運作是否正常的，這時的通訊埠要指定至隨機分配的埠，成功你應該可看到 `Hello World!!!`

```
curl localhost:32769
```

不論你是否有宣告 `EXPOSE` ，其實仍然可以使用 `docker run -p` 直接指定通訊埠的分配

你可以先中止已啟動的容器，再進入下一步。

## ENTRYPOINT 與 CMD

前一個 Task 中，我們有使用到 `ENTRYPOINT` 與 `CMD` ，兩個指令的特性都是在啟動容器時運行指令，而且只有最後一次宣告的會生效，唯一差別只有 `ENTRYPOINT` 不能被替換，而 `CMD` 則是可以被替換的

為了測試這個特性，我們要試著改變 `CMD` 的內容，但不修改 `Dockerfile` ，先觀察目前 `Dockerfile` 的內容 

```
FROM python:alpine

COPY . /app
WORKDIR /app

RUN pip install -r requirements.txt

EXPOSE 5000

ENTRYPOINT ["python"]
CMD ["app.py"]
```

`CMD` 中所指定的是一個檔案，接著我們要在啟動的過程中，替換 `app.py` 改執行其它應用程式

```
docker run -d -p 5000:5000 myapp:v2 replace.py
```

簡易測試運作是否正常的

```
curl localhost:5000
```

成功你應該可看到 `Replaced Hello World~~~`

## VOLUME

<<說明>>

修改您的 Dockerfile 

```
vi Dockerfile
```

增加 `VOLUME` 宣告，我們將目錄 `/app/logs` 建立成為 Volume，並預設啟動程式 `app.py` 替換為 `logging.py`。`logging.py` 這支程式，只會印出目前本機的 `hostname` 並寫入 `/app/logs/myapp.log` 便結束應用程式。最終結果應該如下

```
FROM python:alpine

COPY . /app
WORKDIR /app

RUN pip install -r requirements.txt

VOLUME /app/logs

EXPOSE 5000

ENTRYPOINT ["python"]
CMD ["logging.py"]
``` 

完成後，我們要將修改的內容重新建立，並更換版本代碼至 `v3`

```
docker build -t myapp:v3 . 
```

接著將容器啟動

```
docker run -d -p 5000:5000 myapp:v3
```

容器啟動後，你可以執行 `docker ps` 查看，你會發現容器不存在，或是很快就結束，這是正常的。但因為我們在 Dockerfile 中有宣告 `VOLUME` ，所以即使容器結束了， `VOLUME` 中的內容是仍然是存在的。

輸入以下指令，查看目前所有存在的 volume 

```
docker volume ls
```

你會發現 Docker 自動建立了一個 Volume

```
DRIVER              VOLUME NAME
local               6fd268fb52b198cfd2d1d61b7d3ab7a9a3b2d60dceef4c613d8e6628336782dc
```

為了查看 `VOLUME` 中的資料，我們要先找出真實存放資料的路徑

```
docker volume inspect <YOUR_VOLUME_NAME>
```

你會看到類似以下的內容

```
[
    {
        "CreatedAt": "2019-04-06T06:31:55Z",
        "Driver": "local",
        "Labels": null,
        "Mountpoint": "/var/lib/docker/volumes/6fd268fb52b198cfd2d1d61b7d3ab7a9a3b2d60dceef4c613d8e6628336782dc/_data",
        "Name": "6fd268fb52b198cfd2d1d61b7d3ab7a9a3b2d60dceef4c613d8e6628336782dc",
        "Options": null,
        "Scope": "local"
    }
]
```

其中 `Mountpoint` 就是真實存放資料的路徑，你可以使用 `ls` 指令查看其目錄下的內容。

接下來，我們要試著讓不同的容器，共用相同的 `VOLUME`，目前的 `VOLUME NAME` 難以識別用途，我們重新建立一個較易識別用途的名稱，以下取名為 `myapp-log` ，輸入以下指令建立新的 Volume

```
docker volume create myapp-log
```

接著再次啟動 myapp 時，將先前建立的 `myapp-log` 掛載進入容器之中 

```
docker run -v myapp-log:/app/logs -d myapp:v3
```

以上指令請反覆執行三次以上，每一次執行， `logging.py` 會將執行容器的 `hostname` 寫入日誌檔 `/app/logs/myapp.log` 中，接著我們查看本機端的檔案 

```
cat /var/lib/docker/volumes/myapp-log/_data/myapp.log
```

你應該會看到類似以下的內容

```
INFO:root:ec07fdc67414
INFO:root:d3ccb2556821
INFO:root:f7cd97856867
```

這表示我們成功的讓不同的容器的日誌資料，寫入同一個檔案之中。

---

## 課堂練習-03

* __問題：__ 如果我需要一個建立一個 php + mysql 的服務，要怎麼設計 Dockerfile？

> 提示：ENTRYPOINT 與 CMD 都有只能執行一次的限制

---

## Task 4: Push your images to GCR (Google Container Repository)

輸入以

啟用 `Google Container Repository API` 服務

```
gcloud services enable containerregistry.googleapis.com
```

如果您未啟用 GCR API 你會看到以下的錯誤，若您看到此錯誤，請重新執行以上指令碼 

```
denied: Token exchange failed for project 'systex-lab-f7c658'. Please enable Google Container Registry API in Cloud Console at https://console.cloud.google.com/apis/api/containerregistry.googleapis.com/overview?project=systex-lab-f7c658 before performing this operation.
```

