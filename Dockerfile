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


# STAGE build_powershell
FROM archlinux/base:latest AS build_powershell
RUN pacman -Syu --needed --noconfirm git binutils base-devel icu openssl cmake dotnet-sdk make gcc fakeroot awk busybox
RUN ln -s /bin/busybox /bin/unzip
RUN useradd build --home /mnt --system
RUN git clone https://aur.archlinux.org/powershell.git /mnt
ADD --chown=build:build powershell-packaging-fix.patch /mnt/
RUN chown build:build /mnt -R
# "Ignore" this specific deprecation warning...
RUN sed -ie 's_#warning "The <sys/sysctl.h> header is deprecated and will be removed."__' /usr/include/sys/sysctl.h
USER build
WORKDIR /mnt
RUN patch < powershell-packaging-fix.patch
RUN makepkg


FROM agowa338/ansible:latest
COPY --from=build_terraform /go/bin/terraform /bin/
COPY --chown=root:root --from=build_powershell /mnt/powershell-*-x86_64.pkg.tar.xz /
RUN \
    pacman -U --needed --noconfirm /powershell-*-x86_64.pkg.tar.xz && \
    rm --force /powershell-*-x86_64.pkg.tar.xz && \
    cp /opt/dotnet/shared/Microsoft.NETCore.App/*/*.a /usr/lib/powershell/
RUN ["pwsh", "-Command", "Install-Module -Force VMware.VimAutomation.Core,PowerShellGet,PSScriptAnalyzer,PSReadLine,PackageManagement,Nuget"]
RUN ["pwsh", "-Command", "Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -InvalidCertificateAction Warn -Confirm:$false"]
VOLUME [ "/playbook" ]
ENV isDocker=True
CMD [ "/bin/bash", "/playbook/plays/play.sh" ]
