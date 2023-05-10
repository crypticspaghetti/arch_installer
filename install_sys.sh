#!/usr/bin/env bash
# If you're reading this comment, that's good. Make sure you do read
# every script you plan to run on your computer.

# Install script dependency
pacman -Syu dialog

# Sync time and date via network
timedatectl set-ntp true

# Warn user about loss of data before continuing on
dialog --defaultno --title "Are you sure?" --yesno \
    "This is my personal arch linux install. \n\n\
    It will DESTROY EVERYTHING on your hard disk. \n\n\
    Do not say YES if you are not sure what you are doing! \n\n\
    Do you want to continue?" 15 60 || exit

dialog --no-cancel --inputbox "Enter a name for your computer." \
    10 60 2> comp

# Verify boot (UEFI or BIOS)
uefi=0
ls /sys/firmware/efi/efivar 2> /dev/null && uefi=1

# Choose the disk to use for install
devices_list=($(lsblk -d | awk '{print "/dev/" $1 " " $4 " on"}' \
    | grep -E 'sd|hd|vd|nvme|mmcblk'))

dialog --title "Choose your hard drive" --no-cancel --radiolist \
    "Where do you want to install your new system? \n\n\
    Select with SPACE, confirm with ENTER. \n\n\
    WARNING: Everything on the chosen drive will be DESTROYED!" \
    15 60 4 "${devices_list[@]}" 2> hd

hd=$(cat hd) && rm hd

# Define swap size
default_size="8"
dialog --no-cancel --inputbox \
    "You need three partitions: Boot, Root and Swap \n\
    The boot partition will be 512M \n\
    The root partition will be the remaining of the hard drive \n\n\
    Enter below the partition size (in GB) for the swap. \n\n\
    If you don't enter anything, it will default to ${default_size}G. \n" \
    20 60 2> swap_size
size=$(cat swap_size) && rm swap_size

[[ $size =~ ^[0-9]+$ ]] || size=$default_size

# Nuke the hard drive
dialog --no-cancel \
    --title "!!! DELETE EVERYTHING !!!" \
    --menu "Choose how to wip the hard drive ($hd)" \
    15 60 4 \
    1 "Use dd (zero the disk)" \
    2 "Use shred (slow & secure)" \
    3 "No need - my hard disk is empty" 2> eraser

hderaser=$(cat eraser); rm eraser

function eraseDisk() {
    case $1 in
        1) dd if=/dev/zero of="$hd" status=progress 2>&1 \
            | dialog \
            --title "Formatting $hd..." \
            --progressbox --stdout 20 60;;
        2) shred -v "$hd" \
            | dialog \
            --title "Formatting $hd..." \
            --progressbox --stdout 20 60;;
        3) ;;
    esac
}

eraseDisk "$hderaser"

# Partition hard drive
boot_partition_type=1
[[ "$uefi" == 0 ]] && boot_partition_type=4

# g - create non empty GPT
# n - create new partition
# p - primary partition
# e - extended partition
# w - write the table to disk and exit
partprobe "$hd"
fdisk "$hd" << EOF
g
n


+512M
t
$boot_partition_type
n


+${size}G
n



w
EOF
partprobe "$hd"

# Format partitions
mkswap "${hd}2"
swapon "${hd}2"

mkfs.btrfs "${hd}3" > /dev/null
mount "${hd}3" /mnt

if [ "$uefi" == 1 ]; then
    mkfs.fat -F32 "${hd}1"
    mkdir -p /mnt/boot/efi
    mount "${hd}1" /mnt/boot/efi
fi

pacstrap /mnt base base-devel linux-zen linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab

# Persist variables for next script
echo "$uefi" > /mnt/var_uefi
echo "$hd" > /mnt/var_hd
mv comp /mnt/comp

# Grab our chroot script
curl https://raw.githubusercontent.com/crypticspaghetti\
    /arch_installer/main/install_chroot.sh > /mnt/install_chroot.sh

arch-chroot /mnt bash install_chroot.sh

rm /mnt/var_uefi
rm /mnt/var_hd
rm /mnt/install_chroot.sh

dialog --title "REBOOT!! *tap tap*" --yesno \
    "Congrats! The install is done! \n\n\
    Do you want to reboot?" 20 60

response=$?
case $response in
    0) reboot;;
    1) clear;;
esac

