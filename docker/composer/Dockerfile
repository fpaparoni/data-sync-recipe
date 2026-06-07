FROM alpine:3.19

RUN apk add --no-cache bash curl jq coreutils ca-certificates unzip             && curl -fsSL -o /usr/local/bin/kubectl https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl             && chmod +x /usr/local/bin/kubectl             && curl -fsSL -o helm.tar.gz https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz             && tar -xzf helm.tar.gz             && mv linux-amd64/helm /usr/local/bin/helm             && chmod +x /usr/local/bin/helm             && rm -rf helm.tar.gz linux-amd64             && curl -fsSL -o /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc             && chmod +x /usr/local/bin/mc             && curl -fsSL -o natscli.zip https://github.com/nats-io/natscli/releases/download/v0.1.5/nats-0.1.5-linux-amd64.zip             && unzip -q natscli.zip             && mv nats-0.1.5-linux-amd64/nats /usr/local/bin/nats             && chmod +x /usr/local/bin/nats             && rm -rf natscli.zip nats-0.1.5-linux-amd64             && addgroup -g 1000 composer             && adduser -D -u 1000 -G composer composer

COPY scripts/ /scripts/
RUN find /scripts -name "*.sh" -exec chmod +x {} \;

USER composer
WORKDIR /home/composer
