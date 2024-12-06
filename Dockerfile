FROM ethereum/client-go:v1.10.26

USER root

# Install required packages
RUN apk add --no-cache \
    bash \
    curl \
    git \
    jq \
    vim \
    tree

# Create ethereum data directory
RUN mkdir -p /root/.ethereum/geth

WORKDIR /app

ENTRYPOINT []
CMD ["/bin/bash"]
