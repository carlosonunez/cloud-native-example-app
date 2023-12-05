FROM golang:1.21.0-alpine

RUN apk update --no-cache
RUN apk add git
RUN apk add opentofu --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing/
