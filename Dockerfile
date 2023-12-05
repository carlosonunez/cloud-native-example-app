FROM golang:1.21-alpine AS base
ARG app

RUN mkdir /work
WORKDIR /work
COPY app/$app/go.mod .
RUN go mod download
COPY app/$app/*.go ./
RUN go build -o /app main.go

FROM scratch
COPY --from=base /app /app
ENTRYPOINT [ "/app" ]
