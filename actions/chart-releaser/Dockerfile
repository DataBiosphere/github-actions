FROM alpine

ARG YQ_VERSION=3.3.2
ARG YQ_SHA256=0b0700cfee1d642a0a19f8f9261b2f0a11b7174ef8bcd39e9ed334d9519f0125

ARG RELEASER_VERSION=1.0.0
ARG RELEASER_SHA256=c2851f6268f7432450dce398d938083d002752e894a0a3ae6e9d4740e98a61c2

ARG GITHUB_CLI_VERSION=1.0.0
ARG GITHUB_CLI_SHA256=96575c888d979a6717928fe53bbd75d1acd52a6eec32aa41202d15919475ebfa

RUN apk --update add --no-cache ca-certificates git bash jq moreutils

RUN wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 && \
    sha256sum yq_linux_amd64 | grep ${YQ_SHA256} && \
    mv yq_linux_amd64 /bin/yq && \
    chmod 0755 /bin/yq

RUN wget https://github.com/helm/chart-releaser/releases/download/v${RELEASER_VERSION}/chart-releaser_${RELEASER_VERSION}_linux_amd64.tar.gz -O cr.tar.gz && \
    sha256sum cr.tar.gz | grep ${RELEASER_SHA256} && \
    tar zxvf cr.tar.gz && \
    mv cr /bin/cr && \
    chmod 0755 /bin/cr

RUN wget https://github.com/cli/cli/releases/download/v${GITHUB_CLI_VERSION}/gh_${GITHUB_CLI_VERSION}_linux_amd64.tar.gz -O gh.tar.gz && \
    sha256sum gh.tar.gz | grep ${GITHUB_CLI_SHA256} && \
    tar zxvf gh.tar.gz && \
    mv gh/bin/gh /bin/gh && \
    chmod 0755 /bin/gh

COPY ./contrib/semver ./contrib/semver
RUN install ./contrib/semver /usr/local/bin

RUN mkdir -p /releaser
COPY entrypoint.sh entrypoint.sh
COPY inputs.yaml /releaser/inputs.yaml
RUN chmod +x entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
