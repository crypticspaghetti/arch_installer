#!/usr/bin/env bash

uefi=$(cat /var_uefi); hd=$(cat /var_hd)

cat /comp > /etc/hostname && rm /comp

# Install script dependency
pacman --noconfirm -S dialog

# Install bootloader
pacman --noconfirm -S grub

if [ "$uefi" == 1]; then
    pacman -S --noconfirm efibootmgr
    grub-install --target=x86_64-efi \
        --bootloader-id=GRUB \
        --efi-directory=/boot/efi
else
    grub-install "$hd"
fi

grub-mkconfig -o /boot/grub/grub.cfg

# Clock and timezone
hwclock --systohc

timedatectl set-timezone "US/Central"

# Locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# User creation
function config_user() {
    if [ -z "$1" ]; then
        dialog --no-cancel --inputbox "Please enter the username." \
            10 60 2> name
    else
        echo "$1" > name
    fi

    dialog --no-cancel --passwordbox "Enter the password." \
        10 60 2> pass1
    dialog --no-cancel --passwordbox "Confirm the password." \
        10 60 2> pass2

    while [ "$(cat pass1)" != "$(cat pass2)" ]
    do
        dialog --no-cancel --passwordbox \
            "The passwords do not match.\n\nEnter the password again." \
            10 60 2> pass1
        dialog --no-cancel --passwordbox \
            "Retype the password." \
            10 60 2> pass2
    done
    name=$(cat name) && rm name
    pass=$(cat pass1) && rm pass1 pass2

    # Create the user if they don't exist
    if [[ ! "$(id -u "$name" 2> /dev/null)" ]]; then
        useradd -m -g wheel -s /bin/bash "$name"
    fi

    # Add the password to user
    echo "$name:$pass" | chpasswd
}

dialog --title "Root password" \
    --msgbox "It's time to add a password for the root user." \
    10 60
config_user root

dialog --title "Add user" \
    --msgbox "Let's create a user (will be added to wheel group)." \
    10 60
config_user

echo "$name" > /tmp/username

dialog --title "Continue installation?" --yesno \
"Do you want to install your apps and dotfiles?" \
10 60 \
&& curl https://raw.githubusercontent.com/crypticspaghetti\
/arch_installer/main/install_apps.sh > /tmp/install_apps.sh \
&& bash /tmp/install_apps.sh

