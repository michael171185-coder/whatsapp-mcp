# ===== Stage 1: Go Bridge kompilieren aus Fork =====
FROM golang:1.25-bookworm AS go-builder
WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libsqlite3-dev git \
    && rm -rf /var/lib/apt/lists/*

# Direkt aus Fork klonen
RUN git clone --depth 1 https://github.com/michael171185-coder/whatsapp-mcp.git /src

WORKDIR /src/whatsapp-bridge
RUN go mod download
RUN CGO_ENABLED=1 go build -ldflags="-w -s" -o whatsapp-bridge .

# ===== Stage 2: Runtime =====
FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsqlite3-0 \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app/whatsapp-bridge/store /app/whatsapp-mcp-server
COPY --from=go-builder /src/whatsapp-bridge/whatsapp-bridge /app/whatsapp-bridge/whatsapp-bridge
RUN chmod +x /app/whatsapp-bridge/whatsapp-bridge

WORKDIR /app/whatsapp-mcp-server
COPY --from=go-builder /src/whatsapp-mcp-server/ .

RUN pip install --no-cache-dir uv mcpo && \
    uv sync --frozen

COPY --from=go-builder /src/supervisord.conf /etc/supervisor/conf.d/whatsapp.conf

EXPOSE 8000 8080

VOLUME ["/app/whatsapp-bridge/store"]

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/whatsapp.conf"]
