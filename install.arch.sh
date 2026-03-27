#!/usr/bin/env bash

HOSTNAME="<hostname>"
BOOT_DRIVE="/dev/sda"
USE_GRUB="false" # true to use grub instead of systemd-boot - required for BIOS system installations
KERNEL_VARIANT="-lts" # suffix of the desired linux kernel variant; empty to get default
NETWORK_DEVICE="en*" # used to setup systemd-networkd and DHCP - makes sure network is reconnected correctly if router goes down
TIMEZONE="America/Vancouver"
LOCALE="en_US.UTF-8"
USERNAME="<username>"
FULLNAME="<Full Name>"
PASSWORD=""
SSH_KEY1="<a public SSH key which will be used to login with the newly created account>"
SSH_KEY2="<another public SSH key which will be used to login with the newly created account>"
SSH_KEY3=""
SSH_KEY4=""
PACKAGE_CACHE_SERVER="http://overlord:9129/repo/archlinux" # Custom package cache server, only used if not empty

NPROC="$(nproc)"

if [[ "$PASSWORD" == "" ]]; then
	echo -e "\e[95m\e[1m==>> Generating password for user $USERNAME ...\e[0m"
	PASSWORD="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 64)"
fi

set -e

echo -e "\e[95m\e[1m==>> Updating timedatectl to use ntp ...\e[0m"
timedatectl set-ntp true

echo -e "\e[95m\e[1m==>> Wiping disk: $BOOT_DRIVE ...\e[0m"
wipefs -a -f ${BOOT_DRIVE}

echo -e "\e[95m\e[1m==>> Setting up boot and root partitions in $BOOT_DRIVE ...\e[0m"
if [[ "$USE_GRUB" == "true" ]]; then
	sgdisk -a 1 -n 1:0:+1M -t 1:ef02 -c 1:boot ${BOOT_DRIVE}
else
	sgdisk -n 1:0:+1G -t 1:ef00 -c 1:boot ${BOOT_DRIVE}
fi
sgdisk -n 2:0:0 -t 2:8300 -c 2:root ${BOOT_DRIVE}

echo -e "\e[95m\e[1m==>> The partition table is as follows:\e[0m"
sgdisk -p ${BOOT_DRIVE}

echo -e "\e[95m\e[1m==>> Creating partitions:\e[0m"
if [[ "$USE_GRUB" == "false" ]]; then
	echo -e "\e[95m\e[1m====>> boot ...\e[0m"
	mkfs.fat -F32 "${BOOT_DRIVE}1"
fi
echo -e "\e[95m\e[1m====>> root ...\e[0m"
mkfs.ext4 -F "${BOOT_DRIVE}2"

echo -e "\e[95m\e[1m==>> Mounting boot and root partitions ...\e[0m"
mount "${BOOT_DRIVE}2" /mnt
if [[ "$USE_GRUB" == "false" ]]; then
	mkdir /mnt/boot
	mount "${BOOT_DRIVE}1" /mnt/boot
fi

echo -e "\e[95m\e[1m==>> Bootstrapping the partitions using pacstrap ...\e[0m"
sed -i "s/#ParallelDownloads = [0-9]\+/ParallelDownloads = $(nproc)/g" /etc/pacman.conf

EXTRA_PKGS=""
if [[ "$USE_GRUB" == "true" ]]; then
	EXTRA_PKGS="${EXTRA_PKGS} grub"
fi
pacstrap -K /mnt base base-devel linux$KERNEL_VARIANT linux$KERNEL_VARIANT-headers linux-firmware dkms zsh fish fzf fastfetch neovim tree-sitter-cli unzip less bat openssh git ccache keychain eza man-db cronie cmake $EXTRA_PKGS

echo -e "\e[95m\e[1m==>> Generating mountpoints in fstab using genfstab ...\e[0m"
genfstab -U /mnt >> /mnt/etc/fstab

echo -e "\e[95m\e[1m==>> Performing chroot commands ...\e[0m"
arch-chroot /mnt /bin/bash <<EOF
echo -e "\e[95m\e[1m====>> Seting timezone ...\e[0m"
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

echo -e "\e[95m\e[1m====>> Generating /etc/adjtime ...\e[0m"
hwclock --systohc

echo -e "\e[95m\e[1m====>> Setting locale to $LOCALE ...\e[0m"
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo -e "\e[95m\e[1m====>> Setting hostname as: $HOSTNAME ...\e[0m"
echo "$HOSTNAME" > /etc/hostname

echo -e "\e[95m\e[1m====>> Running mkinitcpio ...\e[0m"
mkinitcpio -P

if [[ "$USE_GRUB" == "true" ]]; then
	echo -e "\e[95m\e[1m====>> Installing grub bootloader ...\e[0m"
	grub-install --target=i386-pc ${BOOT_DRIVE}
	grub-mkconfig -o /boot/grub/grub.cfg
else
	echo -e "\e[95m\e[1m====>> Installing systemd-boot bootloader ...\e[0m"
	bootctl install
	(
		echo "default $HOSTNAME";
		echo "timeout 2";
		echo "editor no";
	) > /boot/loader/loader.conf
	ROOTUUID=$(lsblk -dno UUID ${BOOT_DRIVE}2)
	(
		echo "title	$HOSTNAME";
		echo "linux	/vmlinuz-linux$KERNEL_VARIANT";
		echo "initrd	/initramfs-linux$KERNEL_VARIANT.img";
		echo "options	root=UUID=\$ROOTUUID rw";
	) > /boot/loader/entries/$HOSTNAME.conf
fi

echo -e "\e[95m\e[1m====>> Setting up neovim for root ...\e[0m"
git clone https://github.com/Chirag-Khandelwal/nvim /root/.config/nvim

echo -e "\e[95m\e[1m====>> Setting up profile.d config ...\e[0m"
mkdir -p /etc/profile.d
curl -sL https://raw.githubusercontent.com/Chirag-Khandelwal/dotfiles/refs/heads/main/etc/profile.d/99-custom-vars.sh > /etc/profile.d/99-custom-vars.sh

echo -e "\e[95m\e[1m====>> Creating admin user $USERNAME ...\e[0m"
useradd -mG wheel -s /bin/zsh -c "$FULLNAME" $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

echo -e "\e[95m\e[1m====>> Setting up $USERNAME's shell and vim config ...\e[0m"

echo -e "\e[95m\e[1m======>> Setting up zsh shell ...\e[0m"
curl -sL https://raw.githubusercontent.com/Chirag-Khandelwal/dotfiles/refs/heads/main/.zshrc > /home/$USERNAME/.zshrc
# chown is done after vimrc
echo -e "\e[95m\e[1m======>> Setting up fish shell ...\e[0m"
mkdir -p /home/$USERNAME/.config/fish/functions
curl -sL https://raw.githubusercontent.com/Chirag-Khandelwal/dotfiles/refs/heads/main/.config/fish/functions/l.fish > /home/$USERNAME/.config/fish/functions/l.fish
curl -sL https://raw.githubusercontent.com/Chirag-Khandelwal/dotfiles/refs/heads/main/.config/fish/functions/t.fish > /home/$USERNAME/.config/fish/functions/t.fish
curl -sL https://raw.githubusercontent.com/Chirag-Khandelwal/dotfiles/refs/heads/main/.config/fish/functions/ccd.fish > /home/$USERNAME/.config/fish/functions/ccd.fish
curl -sL https://raw.githubusercontent.com/Chirag-Khandelwal/dotfiles/refs/heads/main/.config/fish/config.fish > /home/$USERNAME/.config/fish/config.fish
# chown is done after nvim setup
echo -e "\e[95m\e[1m======>> Setting up neovim ...\e[0m"
git clone https://github.com/Chirag-Khandelwal/nvim /home/$USERNAME/.config/nvim
chown -R $USERNAME:$USERNAME /home/$USERNAME/.zshrc /home/$USERNAME/.config

echo -e "\e[95m\e[1m====>> Enabling no password sudo for users in wheel group ...\e[0m"
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel-nopasswd

echo -e "\e[95m\e[1m====>> Setting up DHCP network config ...\e[0m"
(
echo "[Match]";
echo "Name=$NETWORK_DEVICE";
echo "";
echo "[Link]";
echo "RequiredForOnline=routable";
echo "";
echo "[Network]";
echo "DHCP=yes";
echo "";
echo "[DHCPv4]";
echo "UseDomains=true";
echo "";
echo "[DHCPv6]";
echo "UseDomains=true";
) > /etc/systemd/network/01-dhcp.network

echo -e "\e[95m\e[1m====>> Setting up ssh server config with authentication key login ...\e[0m"
mkdir -p /home/$USERNAME/.ssh
echo "$SSH_KEY1" > /home/$USERNAME/.ssh/authorized_keys
if [[ "$SSH_KEY2" != "" ]]; then
	echo "$SSH_KEY2" >> /home/$USERNAME/.ssh/authorized_keys
fi
if [[ "$SSH_KEY3" != "" ]]; then
	echo "$SSH_KEY3" >> /home/$USERNAME/.ssh/authorized_keys
fi
if [[ "$SSH_KEY4" != "" ]]; then
	echo "$SSH_KEY4" >> /home/$USERNAME/.ssh/authorized_keys
fi
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
chmod 0600 /home/$USERNAME/.ssh/authorized_keys

echo -e "\e[95m\e[1m====>> Setting up git global user and email configuration ...\e[0m"
su $USERNAME -c 'git config --global user.name "$FULLNAME"'
su $USERNAME -c 'git config --global user.email "$USERNAME@$HOSTNAME"'

echo -e "\e[95m\e[1m====>> Installing Feral ...\e[0m"
cd && mkdir -p git && cd git && git clone https://github.com/Feral-Lang/Feral.git && cd Feral && mkdir build && cd build
cd && cd git/Feral/build && PREFIX_DIR='/usr' cmake .. -DCMAKE_BUILD_TYPE=Release && make -j$NPROC install && cd
feral pkgbootstrap
feral pkg i curl ntfy emoji whattodo

if [[ "$PACKAGE_CACHE_SERVER" != "" ]]; then
	echo -e "\e[95m\e[1m====>> Setting up package cache server ...\e[0m"
	echo 'Server = $PACKAGE_CACHE_SERVER/\$repo/os/\$arch' | cat - /etc/pacman.d/mirrorlist > temp && mv temp /etc/pacman.d/mirrorlist
fi

echo -e "\e[95m\e[1m====>> Setting up AUR Helper: paru ...\e[0m"
su $USERNAME -c 'cd && git clone https://aur.archlinux.org/paru-bin.git && cd paru-bin && makepkg -si --needed --noconfirm --nocheck --noprepare && cd .. && rm -r paru-bin'

echo -e "\e[95m\e[1m====>> Enabling required systemd services ...\e[0m"
systemctl enable cronie sshd systemd-networkd systemd-resolved
EOF

echo -e "\e[95m\e[1m==>> Link /etc/resolv.conf to systemd-resolved's stub ...\e[0m"
ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

echo -e "\e[96m\e[1m==>> User ${USERNAME}'s password: ${PASSWORD}"
echo -e "\e[95m\e[1m==>> Installation Finished!!!\e[0m"