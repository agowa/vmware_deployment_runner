# Mostly hashicorp/terraform:latest but build from master branch,
# as the image is outdated (also use docker multistage build)

# STAGE build_terraform
FROM golang:alpine AS build_terraform
RUN apk add --update git bash openssh zip
ENV TF_DEV=true
ENV TF_RELEASE=true
# Only build the linux x64 version
ENV XC_ARCH=amd64
ENV XC_OS=linux
WORKDIR /go/src/github.com/hashicorp/terraform
RUN git clone https://github.com/hashicorp/terraform.git .
RUN /bin/bash scripts/build.sh

# STAGE 1
# Move to vmware/powerclicore after they fixed there bugs
# and ported all modules to core.
FROM microsoft/powershell:latest AS deployment_runner
RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        less \
        git \
        && \
    rm -rf /var/lib/apt/lists/*
RUN ["pwsh", "-Command", "Install-Module -Force VMware.VimAutomation.Core,PowerShellGet,PSScriptAnalyzer"]
RUN ["pwsh", "-Command", "Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false"]
COPY --from=build_terraform /go/bin/terraform /bin/
VOLUME [ "/data" ]
SHELL [ "pwsh", "-Command" ]
CMD [ "pwsh" ]
