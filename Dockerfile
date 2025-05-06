# Dockerfile
FROM alpine:3.19

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    cronie \
    rclone \
    tzdata

# Set Shoutrrr version
ENV SHOUTRRR_VERSION 0.8.0

# Install Shoutrrr
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
        x86_64) ARCH=amd64 ;; \
        aarch64) ARCH=arm64 ;; \
        armv7l) ARCH=armv6 ;; \
        *) echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac && \
    curl -fL "https://github.com/containrrr/shoutrrr/releases/download/v${SHOUTRRR_VERSION}/shoutrrr_linux_${ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin/ shoutrrr && \
    chmod +x /usr/local/bin/shoutrrr && \
    shoutrrr --version

# Create working directory
RUN mkdir -p /app/backup-scripts
WORKDIR /app

# Copy scripts
COPY entrypoint.sh /app/
COPY backup.sh /app/backup-scripts/

# Make scripts executable
RUN chmod +x /app/entrypoint.sh /app/backup-scripts/backup.sh

# Entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]