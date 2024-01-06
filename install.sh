#! /bin/bash

. setup.conf

boot_partition=${disk}1
root_partition=${disk}2

# Create the partitions
echo "==> Create the partitions ..."
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' <<EOF | gdisk "$disk"
n # new partition
1 # partition number 1
# default - start at beginning of disk
+$boot_partition_size # 512 MB boot partition
ef00 # Hex code or GUID
n # new partition
2 # partition number 2
# default, start immediately after preceding partition
# default, extend partition to end of disk
# default, hex code or GUID
w # write the partition table
Y # and we're done
EOF
echo "==> Create the partitions done!"

# Create file systems
mkfs.fat -F32 $boot_partition

# check
lsblk

echo -n "" > passphrase_file
# Create LUKs container using btrfs
# echo -ne "YES\n\n" | cryptsetup luksFormat --type=luks2 $root_partition
cryptsetup luksFormat --batch-mode --key-file passphrase_file --type=luks2 $root_partition
echo "" | cryptsetup open $root_partition archlinux
rm passphrase_file

root_mapper='/dev/mapper/archlinux'
mkfs.btrfs -L "Arch Linux" $root_mapper -f

mount $root_mapper /mnt
cd /mnt
btrfs subvolume create @
btrfs subvolume create @home
btrfs subvolume create @snapshots
btrfs subvolume create @var_log
btrfs subvolume create @swap # if using swap
echo "create sub volume done"

cd
umount /mnt
mount -o noatime,compress=zstd,space_cache=v2,subvol=@ $root_mapper /mnt
mkdir -p /mnt/{boot,home,.snapshots,var/log,swap}
mount -o noatime,compress=zstd,space_cache=v2,subvol=@home $root_mapper /mnt/home
mount -o noatime,compress=zstd,space_cache=v2,subvol=@snapshots $root_mapper /mnt/.snapshots
mount -o noatime,compress=zstd,space_cache=v2,subvol=@var_log $root_mapper /mnt/var/log
mount -o noatime,compress=zstd,space_cache=v2,subvol=@swap $root_mapper /mnt/swap
echo "monut sub module done"

#mount -o subvol=@root /dev/mapper/archlinux /mnt
#mkdir /mnt/{var,home,swap}
#mount -o subvol=@var /dev/mapper/archlinux /mnt/var
#mount -o subvol=@home /dev/mapper/archlinux /mnt/home
#mount -o subvol=@swap /dev/mapper/archlinux /mnt/swap # if using swap

# convert swap size to Mib
swap_size_mb=0
if [[ $swap_size == *M* ]]; then
    swap_size_mb=$(echo $swap_size | sed '/sM//')
elif [[ $swap_size == *G* ]]; then
    swap_size_mb=$(echo $swap_size | sed 's/G/*1024/' | bc)
fi

cd /mnt/swap
chattr +C /mnt/swap
dd if=/dev/zero of=swapfile bs=1M count=$swap_size_mb status=progress
chmod 600 swapfile
mkswap swapfile
swapon swapfile
echo "create swap done"

#truncate -s 0 /mnt/swap/swapfile
#chattr +C /mnt/swap/swapfile
#dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=$swap_size status=progress
#chmod 600 /mnt/swap/swapfile
#mkswap /mnt/swap/swapfile
#swapon /mnt/swap/swapfile

mkdir /mnt/boot
mount $boot_partition /mnt/boot
echo "==> Mount the partitions done!"

# Setup time
timedatectl set-ntp true

# Install Arch linux
echo "Setup done. Starting install ..."
echo "Install Arch linux and package: sudo"
pacman -S archlinux-keyring
pacstrap /mnt base base-devel linux linux-firmware sudo btrfs-progs git efibootmgr networkmanager network-manager-applet ${ucode}-ucode

# Generate fstab
genfstab -U /mnt >>/mnt/etc/fstab

if [[ ! -f chroot.sh ]]; then
  echo "Missing chroot.sh, Downloading..."
  curl -O https://raw.githubusercontent.com/thanbv1510/linux-setup/master/chroot.sh
fi

cp -rfv chroot.sh /mnt
cp -rfv setup.conf /mnt

chmod +x /mnt/chroot.sh
arch-chroot /mnt /chroot.sh
