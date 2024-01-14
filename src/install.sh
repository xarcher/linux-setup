#! /bin/bash

. setup.conf
. utils.sh

boot_partition="${disk}${disk_separate_partition}1"
root_partition="${disk}${disk_separate_partition}2"

# Create the partitions
echo "==> Creating the partitions(boot = ${boot_partition}, root = ${root_partition}"
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

lsblk

echo "<== Create the partitions done!"

# Create file systems
mkfs.fat -F32 -n EFI $boot_partition

echo -n ${passphrase_luks} > passphrase_file
# Create LUKs container using btrfs
cryptsetup luksFormat --batch-mode --key-file passphrase_file --type=luks2 $root_partition
echo ${passphrase_luks} | cryptsetup open $root_partition luks
rm passphrase_file

mkfs.btrfs -L ROOT $root_mapper -f

mount $root_mapper /mnt
cd /mnt || exit
btrfs sub create /mnt/@
btrfs sub create /mnt/@swap
btrfs sub create /mnt/@home
btrfs sub create /mnt/@pkg
btrfs sub create /mnt/@snapshots

umount /mnt
echo "==> create sub volume done!"

cd && umount /mnt
mount -o noatime,nodiratime,compress=zstd,space_cache=v2,ssd,subvol=@ $root_mapper /mnt
mkdir -p /mnt/{boot,home,var/cache/pacman/pkg,.snapshots,btrfs}
mount -o noatime,nodiratime,compress=zstd,space_cache=v2,ssd,subvol=@home $root_mapper /mnt/home
mount -o noatime,nodiratime,compress=zstd,space_cache=v2,ssd,subvol=@pkg $root_mapper /mnt/var/cache/pacman/pkg
mount -o noatime,nodiratime,compress=zstd,space_cache=v2,ssd,subvol=@snapshots $root_mapper /mnt/.snapshots
mount -o noatime,nodiratime,compress=zstd,space_cache=v2,ssd,subvolid=5 $root_mapper /mnt/btrfs
echo "==> mount sub module done!"

mount $boot_partition /mnt/boot
echo "==> Mount the EFI partition done!"

# convert swap size to Mib
swap_size_mb=$(convertToMib ${swap_size})
cd /mnt/btrfs/@swap || exit
truncate -s 0 ./swapfile
chattr +C ./swapfile
btrfs property set ./swapfile compression none
dd if=/dev/zero of=./swapfile bs=1M count=$swap_size_mb status=progress
chmod 600 ./swapfile
mkswap ./swapfile
swapon ./swapfile
cd - || exit
echo "==> create swap done!"

# Setup time
timedatectl set-ntp true

# Install Arch linux
echo "==> Setup done. Starting install ..."
pacman -S archlinux-keyring
pacstrap -K /mnt base base-devel linux linux-firmware sudo btrfs-progs git efibootmgr ${ucode}-ucode networkmanager

# Generate fstab
genfstab -U /mnt >>/mnt/etc/fstab

cd && cd linux-setup/src || exit

cp -rfv chroot.sh /mnt
cp -rfv setup.conf /mnt

chmod +x /mnt/chroot.sh
arch-chroot /mnt /chroot.sh