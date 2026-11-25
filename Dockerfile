FROM ubuntu:24.04

# Предотвращаем интерактивные запросы при установке
ENV DEBIAN_FRONTEND=noninteractive

# Установка базовых зависимостей
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    git \
    lsb-release \
    unzip \
    rpm \
    qemu-system-x86 \
    qemu-utils \
    cloud-utils \
    genisoimage \
    ruby \
    ruby-dev \
    build-essential \
    zlib1g-dev \
    libguestfs-tools \
    && rm -rf /var/lib/apt/lists/*

# Установка Packer из зеркала Yandex (версия 1.16.2)
RUN curl -fsSL https://mirror.yandex.ru/mirrors/releases.hashicorp.com/packer/1.16.2/packer_1.16.2_linux_amd64.zip -o /tmp/packer.zip && \
    unzip /tmp/packer.zip -d /usr/local/bin && \
    rm /tmp/packer.zip

# Установка FPM (через Ruby Gems)
RUN gem install fpm

WORKDIR /workspace
