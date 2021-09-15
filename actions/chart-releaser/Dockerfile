FROM gcr.io/google.com/cloudsdktool/cloud-sdk:alpine

ARG YQ_VERSION=3.3.2
ARG YQ_SHA256=0b0700cfee1d642a0a19f8f9261b2f0a11b7174ef8bcd39e9ed334d9519f0125

ARG RELEASER_VERSION=1.0.0
ARG RELEASER_SHA256=c2851f6268f7432450dce398d938083d002752e894a0a3ae6e9d4740e98a61c2

ARG HELM_VERSION=v3.2.1
ARG HELM_LOCATION=https://get.helm.sh
ARG HELM_FILENAME=helm-v3.2.1-linux-amd64.tar.gz
ARG HELM_SHA256=018f9908cb950701a5d59e757653a790c66d8eda288625dbb185354ca6f41f6b

RUN apk --update add --no-cache ca-certificates git bash jq moreutils curl

RUN wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 && \
    sha256sum yq_linux_amd64 | grep ${YQ_SHA256} && \
    mv yq_linux_amd64 /bin/yq && \
    chmod 0755 /bin/yq

RUN wget https://github.com/helm/chart-releaser/releases/download/v${RELEASER_VERSION}/chart-releaser_${RELEASER_VERSION}_linux_amd64.tar.gz -O cr.tar.gz && \
    sha256sum cr.tar.gz | grep ${RELEASER_SHA256} && \
    tar zxvf cr.tar.gz && \
    mv cr /bin/cr && \
    chmod 0755 /bin/cr

RUN wget ${HELM_LOCATION}/${HELM_FILENAME} && \
    echo Verifying ${HELM_FILENAME}... && \
    sha256sum ${HELM_FILENAME} | grep -q "${HELM_SHA256}" && \
    echo Extracting ${HELM_FILENAME}... && \
    tar zxvf ${HELM_FILENAME} && \
    mv /linux-amd64/helm /usr/local/bin/ && \
    rm ${HELM_FILENAME} && rm -r /linux-amd64

COPY ./contrib/semver ./contrib/semver
RUN install ./contrib/semver /usr/local/bin

RUN mkdir -p /releaser
COPY entrypoint.sh entrypoint.sh
COPY inputs.yaml /releaser/inputs.yaml
RUN chmod +x entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
