FROM alpine:3.12

ARG YQ_VERSION=3.3.2
ARG YQ_SHA256=0b0700cfee1d642a0a19f8f9261b2f0a11b7174ef8bcd39e9ed334d9519f0125

RUN apk --update add --no-cache bash curl jq moreutils

RUN wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 && \
    sha256sum yq_linux_amd64 | grep ${YQ_SHA256} && \
    mv yq_linux_amd64 /bin/yq && \
    chmod 0755 /bin/yq

RUN mkdir -p /test
COPY inputs.yaml /test/inputs.yaml
COPY entrypoint.sh entrypoint.sh
RUN chmod +x entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
