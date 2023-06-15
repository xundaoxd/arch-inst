#!/bin/bash
set -e

hostname='xundaoxd-pc'
user="xundaoxd"

rootdisk="/dev/nvme0n1p2"

# disk : mount point : mount options : format options
volumes=(
    "$rootdisk:/mnt:-o subvol=/@root:"
    "$rootdisk:/mnt/home:-o subvol=/@home:"
    "$rootdisk:/mnt/mnt/snapshots:-o subvol=/@snapshots:"
    "/dev/nvme0n1p1:/mnt/boot/efi::fat -F 32"
)

mnt_vols() {
    for vol in "${volumes[@]}"; do
        IFS=: read -r -a info <<< "$vol"
        [[ -n "${info[3]}" ]] && mkfs.${info[3]} "${info[0]}"
        mkdir -p "${info[1]}"
        [[ -n "${info[1]}" ]] && mount ${info[2]} "${info[0]}" "${info[1]}"
    done
}

prepare() {
    # systemctl stop reflector
    # reflector --verbose --country China --protocol http --protocol https --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

    mkfs.btrfs -f -L rootdisk $rootdisk
    mount $rootdisk /mnt
    btrfs subvol create /mnt/@root
    btrfs subvol create /mnt/@home
    btrfs subvol create /mnt/@snapshots
    umount -R /mnt

    mnt_vols
    pacstrap /mnt base base-devel linux-lts linux-firmware btrfs-progs
    genfstab -U /mnt >> /mnt/etc/fstab
    cp install.sh /mnt/root/
    arch-chroot /mnt /root/install.sh install
    rm -rf  /mnt/root/install.sh
    umount -R /mnt

    mount $rootdisk /mnt
    ./snapshot init
    umount -R /mnt
}

install() {
    echo $hostname > /etc/hostname
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    echo -e 'en_US.UTF-8 UTF-8\nzh_CN.UTF-8 UTF-8' >> /etc/locale.gen
    echo 'LANG=en_US.UTF-8' > /etc/locale.conf
    locale-gen

    # kernel
    mkinitcpio -P

    # boot
    pacman -S --noconfirm grub efibootmgr
    grub-install --efi-directory=/boot/efi --recheck
    grub-mkconfig -o /boot/grub/grub.cfg

    # video and sound
    pacman -S --noconfirm nvidia-lts alsa-utils alsa-firmware pulseaudio pulseaudio-alsa pulseaudio-bluetooth bluez bluez-utils
    systemctl enable bluetooth

    # network
    pacman -S --noconfirm networkmanager openssh
    systemctl enable NetworkManager
    systemctl enable sshd

    # misc and account
    pacman -S --noconfirm polkit sudo zsh neovim git unzip

    useradd -m -s /bin/zsh $user
    usermod -aG wheel $user
    EDITOR=nvim visudo
    echo "set $user password."
    passwd $user

    # desktop
    pacman -S --noconfirm xorg xorg-xprop sddm bspwm sxhkd alacritty \
        i3lock xss-lock polybar picom rofi feh ranger
    systemctl enable sddm
    su - $user -c 'install -Dm755 /usr/share/doc/bspwm/examples/bspwmrc ~/.config/bspwm/bspwmrc'
    su - $user -c 'install -Dm644 /usr/share/doc/bspwm/examples/sxhkdrc ~/.config/sxhkd/sxhkdrc'
    su - $user -c 'sed -i "s/urxvt/alacritty/" ~/.config/sxhkd/sxhkdrc'
}

if [[ $# -eq 1 ]]; then
    $1
else
    prepare
fi

