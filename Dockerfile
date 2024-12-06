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

WORKDIR /app

ENTRYPOINT []
CMD ["/bin/bash"]
