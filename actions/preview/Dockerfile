FROM google/cloud-sdk:alpine

ARG KUBECTL_VERSION=v1.14.5
ARG KUBECTL_SHA256=26681319de56820a8467c9407e9203d5b15fb010ffc75ac5b99c9945ad0bd28c

ARG HELM_VERSION=v3.2.1
ARG HELM_LOCATION=https://get.helm.sh
ARG HELM_FILENAME=helm-v3.2.1-linux-amd64.tar.gz
ARG HELM_SHA256=018f9908cb950701a5d59e757653a790c66d8eda288625dbb185354ca6f41f6b

ARG HELMFILE_VERSION=v0.114.0
ARG HELMFILE_SHA256=dd074934188ac11275109a01f98eb0651d49c1566ddf3141dc71236e96b31535

ARG YQ_VERSION=3.3.2
ARG YQ_SHA256=0b0700cfee1d642a0a19f8f9261b2f0a11b7174ef8bcd39e9ed334d9519f0125

ARG TERRAFORM_VERSION=0.12.29
ARG TERRAFORM_SHA256=872245d9c6302b24dc0d98a1e010aef1e4ef60865a2d1f60102c8ad03e9d5a1d

LABEL "repository"="https://github.com/DataBiosphere/github-actions/tree/master/actions/preview"
LABEL "homepage"="https://github.com/DataBiosphere/github-actions/tree/master/actions/preview"

USER root

RUN apk --update add --no-cache ca-certificates git bash curl jq moreutils

RUN curl --retry 3 --retry-connrefused -LO "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    sha256sum kubectl | grep ${KUBECTL_SHA256} && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/kubectl

RUN wget ${HELM_LOCATION}/${HELM_FILENAME} && \
    echo Verifying ${HELM_FILENAME}... && \
    sha256sum ${HELM_FILENAME} | grep -q "${HELM_SHA256}" && \
    echo Extracting ${HELM_FILENAME}... && \
    tar zxvf ${HELM_FILENAME} && \
    mv /linux-amd64/helm /usr/local/bin/ && \
    rm ${HELM_FILENAME} && rm -r /linux-amd64

RUN helm plugin install https://github.com/databus23/helm-diff --version v3.0.0-rc.7

RUN wget https://github.com/roboll/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_linux_amd64 && \
    sha256sum helmfile_linux_amd64 | grep ${HELMFILE_SHA256} && \
    mv helmfile_linux_amd64 /bin/helmfile && \
    chmod 0755 /bin/helmfile

RUN wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 && \
    sha256sum yq_linux_amd64 | grep ${YQ_SHA256} && \
    mv yq_linux_amd64 /bin/yq && \
    chmod 0755 /bin/yq

RUN wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -O terraform_linux_amd64.zip && \
    sha256sum terraform_linux_amd64.zip | grep ${TERRAFORM_SHA256} && \
    unzip terraform_linux_amd64.zip -d /bin

RUN mkdir -p /preview
COPY terraform /preview/terraform
COPY entrypoint.sh entrypoint.sh
COPY inputs.yaml /preview/inputs.yaml
COPY services.yaml /preview/services.yaml
RUN chmod +x entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
