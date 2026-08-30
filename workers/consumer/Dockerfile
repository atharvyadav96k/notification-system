FROM golang:1.25 AS builder

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY worker.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o /worker .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates
COPY --from=builder /worker /usr/local/bin/worker
ENTRYPOINT ["/usr/local/bin/worker"]
