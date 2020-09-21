FROM alpine/git

COPY ./contrib/semver ./contrib/semver
RUN install ./contrib/semver /usr/local/bin

RUN mkdir -p /releaser
COPY entrypoint.sh entrypoint.sh
COPY inputs.yaml /releaser/inputs.yaml
RUN chmod +x entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
