FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o intent-compiler main.go

FROM gcr.io/distroless/static-debian11
COPY --from=builder /app/intent-compiler /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/intent-compiler"]