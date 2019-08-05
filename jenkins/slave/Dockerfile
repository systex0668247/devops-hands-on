FROM jenkins/jnlp-slave:alpine

USER root

ENV TZ="Asia/Taipei"

RUN apk add curl wget \    
    # Add default timezone
    && apk add tzdata \
    && cp /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone \
    
    # Install envsubst command for replacing config files in system startup
    # - it needs libintl package
    # - only weights 100KB combined with it's libraries
    && apk add gettext libintl \

    # Cleanup
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/*
    
WORKDIR /opt

# Add docker client
ENV DOCKER_VERSION 18.03.1-ce

RUN wget https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz \
    && tar -zxvf docker-${DOCKER_VERSION}.tgz \
    && cp docker/docker /usr/bin/ \
    && rm -rf /opt/docker* \
    
    # Add kubectl client
    && wget https://storage.googleapis.com/kubernetes-release/release/v1.14.1/bin/linux/amd64/kubectl \
    && chmod +x kubectl \
    && mv kubectl /usr/bin/ \
    
    # Add mvn for practice
    && wget http://ftp.twaren.net/Unix/Web/apache/maven/maven-3/3.6.1/binaries/apache-maven-3.6.1-bin.tar.gz \
    && tar zxvf apache-maven-3.6.1-bin.tar.gz \ 
    && rm -rf apache-maven-3.6.1-bin.tar.gz \
    
    # Add Helm support
    && wget https://kubernetes-helm.storage.googleapis.com/helm-v2.13.1-linux-amd64.tar.gz \
    && tar zxvf helm-v2.13.1-linux-amd64.tar.gz \
    && mv linux-amd64/helm /usr/bin \
    && mv linux-amd64/tiller /usr/bin \
    && rm -rf /opt/helm* /opt/linux-amd64* 

ENV PATH=$PATH:/opt/apache-maven-3.6.1/bin 
    

ENTRYPOINT ["jenkins-slave"]    
