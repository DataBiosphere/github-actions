ARG GO_VERSION='1.15'
ARG ALPINE_VERSION='3.12'

FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} as build
WORKDIR /build
ENV CGO_ENABLED=0
ENV GO111MODULE=on
ENV GOBIN=/bin
ARG DELVE_VERSION='v1.5.0'
RUN go get github.com/go-delve/delve/cmd/dlv@${DELVE_VERSION}
COPY go.mod go.sum ./
#COPY ./internal/imports ./internal/imports
#RUN go build ./intrnal/imports
COPY . .
RUN go build -o /bin/locker ./...

FROM build as debug
# When debugging locally, local ADC JSON can be mounted
ARG GOOGLE_JSON='/gcloud/application_default_credentials.json'
ENV GOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_JSON}
CMD dlv -l :50000 --headless=true --api-version=2 debug ./...

FROM alpine:${ALPINE_VERSION} as runtime
# GitHub Actions mount the workflow workspace.
# We expect a Google Service Account JSON there,
# created by an earlier step in the workflow.
ARG GOOGLE_JSON='/github/workspace/service_account.json'
ENV GOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_JSON}
COPY --from=build /bin/locker /bin/locker
ENTRYPOINT ["/bin/locker"]
