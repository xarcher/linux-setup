#! /bin/bash

. setup.conf

root_partition=$disk$root_partition_idx

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
echo 'default arch' >/boot/loader/loader.conf
echo 'timeout 0' >>/boot/loader/loader.conf
echo 'editor  0' >>/boot/loader/loader.conf

uuid="cryptsetup luksUUID $root_partition"

# Create the arch.conf file in the entries directory and Edit the details for the arch.conf file
echo "title   Arch Linux" >/boot/loader/entries/arch.conf
echo "linux   /vmlinuz-linux" >>/boot/loader/entries/arch.conf
echo "initrd  /$ucode-ucode.img"  >>/boot/loader/entries/arch.conf
echo "initrd  /initramfs-linux.img" >>/boot/loader/entries/arch.conf
echo "options rw luks.uuid=$uuid luks.name=<uuid>=luks root=/dev/mapper/luks rootflags=subvol=@root" >>/boot/loader/entries/arch.conf

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
sed -i 's/HOOKS=()/HOOKS=(base systemd autodetect modconf block keyboard sd-vconsole sd-encrypt filesystems)/g' /etc/mkinitcpio.conf

# Recreate initramfs
mkinitcpio -p linux

# Cleanup
#rm install.sh
#rm chroot.sh

echo "$ umount -R /mnt"
echo "$ reboot"
exit
