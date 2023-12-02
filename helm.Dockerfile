FROM busybox:1.36.1 AS base
ARG HELM_VERSION=3.13.2
ARG ARCH=arm64

WORKDIR /tmp
RUN wget -O ./helm.tar.gz https://get.helm.sh/helm-v${HELM_VERSION}-linux-${ARCH}.tar.gz
RUN tar -xvzf ./helm.tar.gz
RUN mv linux-${ARCH}/helm /tmp

FROM scratch
COPY --from=base /tmp/helm /helm
ENTRYPOINT [ "/helm" ]
