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
ENV GO111MODULE=on
WORKDIR /go/src/github.com/hashicorp/terraform
RUN git clone https://github.com/hashicorp/terraform.git .
RUN /bin/bash scripts/build.sh
RUN go mod vendor
RUN /bin/bash scripts/build.sh


# STAGE build_powershell
FROM archlinux/base:latest AS build_powershell
RUN pacman -Syu --needed --noconfirm git binutils base-devel icu openssl cmake dotnet-sdk make gcc fakeroot awk busybox lttng-ust openssl-1.0
RUN ln -s /bin/busybox /bin/unzip
RUN useradd build --home /mnt --system
RUN git clone https://aur.archlinux.org/powershell-bin.git /mnt
RUN chown build:build /mnt -R
USER build
WORKDIR /mnt
RUN makepkg


FROM agowa338/ansible:latest
COPY --from=build_terraform /go/bin/terraform /bin/
COPY --chown=root:root --from=build_powershell /mnt/powershell-*-x86_64.pkg.tar.xz /
RUN \
    pacman -Syy && \
    pacman -U --needed --noconfirm /powershell-*-x86_64.pkg.tar.xz && \
    rm --force /powershell-*-x86_64.pkg.tar.xz
RUN ["pwsh", "-Command", "Install-Module -Force VMware.VimAutomation.Core,PowerShellGet,PSScriptAnalyzer,PSReadLine,PackageManagement,NuGet"]
RUN ["pwsh", "-Command", "Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -InvalidCertificateAction Warn -Confirm:$false"]
VOLUME [ "/playbook" ]
ENV isDocker=True
CMD [ "/bin/bash", "/playbook/plays/play.sh" ]
