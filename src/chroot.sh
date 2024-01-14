#! /bin/bash

. setup.conf

root_partition=${disk}2

# Setup Time zone
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime

# Run hwclock to generate /etc/adjtime
hwclock --systohc --utc

# Generate the locales
sed -i '/en_US.UTF-8 UTF-8/s/^#//g' /etc/locale.gen
locale-gen

# Create the locale.conf file, and set the LANG variable
echo "LANG=en_US.UTF-8" >/etc/locale.conf

# Create the hostname file
echo "$hostname" >/etc/hostname

# Add matching entries to hosts
echo "127.0.1.1 localhost.localdomain $hostname" >>/etc/hosts

# Network manager
sudo pacman -S networkmanager --noconfirm

package=networkmanager
if pacman -Qs networkmanager >/dev/null; then
  echo "==> The package $package is installed"
else
  echo "<== The package $package is not installed"
  sudo pacman -S networkmanager --noconfirm
fi

# Setup Network manager
systemctl enable NetworkManager
echo "==> Setup Network manager done!"

# Root password
echo "==> Set root password:"
echo -e "$root_passwd\n$root_passwd\n" | passwd
echo "==> Set root password done!"

# Install Boot loader
bootctl --path=/boot install

# Edit the loader.conf file
echo 'default arch.conf' >/boot/loader/loader.conf
echo 'timeout 0' >>/boot/loader/loader.conf
echo 'console-mode max' >>/boot/loader/loader.conf
echo 'editor  0' >>/boot/loader/loader.conf

uuid="$(cryptsetup luksUUID $root_partition)"
offset="$(btrfs inspect-internal map-swapfile -r /swap/swapfile)"

echo "==> uuid = $uuid, resume offset = $offset"

# Create the arch.conf file in the entries directory and Edit the details for the arch.conf file
echo "title   Arch Linux" >/boot/loader/entries/arch.conf
echo "linux   /vmlinuz-linux" >>/boot/loader/entries/arch.conf
echo "initrd  /$ucode-ucode.img"  >>/boot/loader/entries/arch.conf
echo "initrd  /initramfs-linux.img" >>/boot/loader/entries/arch.conf
echo "options cryptdevice=UUID=$uuid:luks:allow-discards root=$root_mapper rootflags=subvol=@ rd.luks.options=discard rw resume=$root_mapper resume_offset=$offset" >>/boot/loader/entries/arch.conf
echo "==> Setup bootloader done!"

# Add user
useradd -m -G wheel -s /bin/bash -c "$full_name" "$username"
echo "==> Set user password:"
echo -e "$user_passwd\n$user_passwd\n" | passwd $username
echo "==> Set user password done!"

# Allow users in group wheel to use sudo
sed -i 's/^#\s*\(%wheel\s*ALL=(ALL:ALL)\s*ALL\)/\1/g' /etc/sudoers

# Configure the creation of initramfs
sed -i 's/MODULES=()/MODULES=(btrfs)/g' /etc/mkinitcpio.conf
sed -i 's/HOOKS=()/HOOKS=(base keyboard udev autodetect modconf block keymap encrypt btrfs filesystems resume)/g' /etc/mkinitcpio.conf

# Recreate initramfs
mkinitcpio -p linux

echo "==> Yay! Setup done, please run: exit && umount -R /mnt && reboot"