#!/bin/bash
set -e
user="xundaoxd"

pacman -S --noconfirm man-db man-pages

echo -e '[archlinuxcn]\nServer = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch\n' >> /etc/pacman.conf \
    && pacman -Syy \
    && pacman -S --noconfirm archlinuxcn-keyring \
    && pacman -S --noconfirm yay

pacman -S --noconfirm docker \
    && systemctl enable docker \
    && usermod -aG docker $user
# yay -S --noconfirm nvidia-container-toolkit

pacman -S --noconfirm virt-manager dnsmasq qemu-full \
    && systemctl enable libvirtd \
    && usermod -aG libvirt $user \
    && sed -i '/^unix_sock_group/{s/#//}' /etc/libvirt/libvirtd.conf

pacman -S --noconfirm xclip unzip ripgrep-all openbsd-netcat docker-compose ctags

