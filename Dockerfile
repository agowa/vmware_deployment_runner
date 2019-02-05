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


# STAGE build_powershell
FROM archlinux/base:latest AS build_powershell
RUN pacman -Syu --needed --noconfirm git binutils base-devel icu openssl cmake dotnet-sdk make gcc fakeroot awk busybox
RUN ln -s /bin/busybox /bin/unzip
RUN useradd build --home /mnt --system
RUN git clone https://aur.archlinux.org/powershell.git /mnt
ADD --chown=build:build powershell-packaging-fix.patch /mnt/
RUN chown build:build /mnt -R
USER build
WORKDIR /mnt
RUN git apply powershell-packaging-fix.patch
RUN makepkg


FROM archlinux/base:latest
RUN pacman -Syu --needed --noconfirm \
    && pacman -S --needed --noconfirm \
        bash \
        python2 \
        python \
        lsb-release \
        curl \
        wget \
        git \
        git-lfs \
        ca-certificates \
        gzip \
        unzip \
        tar \
        sudo \
        openssh \
        python2-yaml \
        python2-jinja \
        python2-httplib2 \
        python2-boto \
        python2-openstackclient \
        python2-pip \
        python-pip \
        python-crypto \
        python-jinja \
        python-paramiko \
        python-yaml \
        acme-tiny \
        python-boto3 \
        python-dnspython \
        python-jmespath \
        python-netaddr \
        python-ovirt-engine-sdk \
        python-passlib \
        python-pyopenssl \
        python-pywinrm \
        python-systemd \
        python-openstackclient \
        sshpass \
        fakeroot \
        python-setuptools \
        ansible \
        ansible-lint \
        binutils \
        icu \
        openssl \
        dotnet-sdk \
        less \
    && mkdir /var/cache/pacman/pkg/ \
    && pacman -Sc --noconfirm \
    && pip3 install \
        python-openstackclient \
        python-designateclient \
        shade \
    && pip2 install \
        python-openstackclient \
        python-designateclient \
        shade

COPY --from=build_terraform /go/bin/terraform /bin/
COPY --chown=root:root --from=build_powershell /mnt/powershell-6.1.2-1-x86_64.pkg.tar.xz /
RUN \
    pacman -U --needed --noconfirm /powershell-6.1.2-1-x86_64.pkg.tar.xz && \
    rm --force /powershell-6.1.2-1-x86_64.pkg.tar.xz && \
    cp /opt/dotnet/shared/Microsoft.NETCore.App/2.2.0/*.a /usr/lib/powershell/
RUN ["pwsh", "-Command", "Install-Module -Force VMware.VimAutomation.Core,PowerShellGet,PSScriptAnalyzer,PSReadLine,PackageManagement,Nuget"]
RUN ["pwsh", "-Command", "Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -InvalidCertificateAction Warn -Confirm:$false"]
VOLUME [ "/playbook" ]
ENV isDocker=True
CMD [ "/bin/bash", "/playbook/plays/play.sh" ]
