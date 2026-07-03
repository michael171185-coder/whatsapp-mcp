# ===== Stage 1: Go Bridge statisch kompilieren (für glibc-Kompatibilität) =====
FROM golang:1.25-bookworm AS go-builder
WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

COPY whatsapp-bridge/go.mod whatsapp-bridge/go.sum ./
RUN GOTOOLCHAIN=local go mod download

COPY whatsapp-bridge/main.go .
RUN GOTOOLCHAIN=local CGO_ENABLED=1 go build -ldflags="-w -s" -o whatsapp-bridge .

# ===== Stage 2: Runtime =====
FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsqlite3-0 \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Go-Bridge
RUN mkdir -p /app/whatsapp-bridge/store /app/whatsapp-mcp-server
COPY --from=go-builder /build/whatsapp-bridge /app/whatsapp-bridge/whatsapp-bridge
RUN chmod +x /app/whatsapp-bridge/whatsapp-bridge

# Python MCP-Server
WORKDIR /app/whatsapp-mcp-server
COPY whatsapp-mcp-server/ .

# uv + deps installieren; mcpo global via pip
RUN pip install --no-cache-dir uv mcpo && \
    uv sync --frozen

# Supervisor Konfiguration
COPY supervisord.conf /etc/supervisor/conf.d/whatsapp.conf

EXPOSE 8000

VOLUME ["/app/whatsapp-bridge/store"]

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/whatsapp.conf"]
