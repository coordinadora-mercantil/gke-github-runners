FROM ubuntu:20.04

RUN apt-get -qqy update && \
    apt-get -qqy upgrade && \
    apt-get -qqy install \
    curl \
    iputils-ping \
    tar \
    python

RUN curl -fsSL https://get.docker.com -o- | sh && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

ARG GH_RUNNER_VERSION="2.277.1"

WORKDIR /runner

RUN curl -o actions.tar.gz --location "https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz" && \
    tar -zxf actions.tar.gz && \
    rm -f actions.tar.gz && \
    ./bin/installdependencies.sh

COPY entrypoint.sh .
RUN chmod +x entrypoint.sh
ENTRYPOINT ["/runner/entrypoint.sh"]
