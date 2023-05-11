#!/usr/bin/env bash

# Create common user directories
xdg-user-dirs-update

# AUR helper functions
aur_install() {
    curl -O "https://aur.archlinux.org/cgit/aur.git/snapshot/$1.tar.gz" \
        && tar -xvf "$1.tar.gz" \
        && cd "$1" \
        && makepkg --noconfirm -si \
        && cd - \
        && rm -rf "$1" "$1.tar.gz"
}

aur_check() {
    qm=$(pacman -Qm | awk '{ print $1 }')
    for arg in "$@"
    do
        if [[ "$qm" != *"$arg"* ]]; then
            sudo aura --noconfirm -A "$arg" &>> /tmp/aur_install \
                || aur_install "$arg" &>> /tmp/aur_install
        fi
    done 
}

cd /tmp
dialog --infobox "Installing \"Aura\", an AUR helper" 10 60
aur_check aura

# Install AUR packages
count=$(wc -l < /tmp/aur_queue)
c=0
cat /tmp/aur_queue | while read -r line
do
    c=$(( "$c" + 1 ))
    dialog --infobox \
        "AUR install - Downloading and installing app $c out of $count: $line..." \
        10 60
    aur_check "$line"
done

# Install dotfiles
DOTFILES="/home/$(whoami)/dotfiles"
if [ ! -d "$DOTFILES" ]; then
    git clone https://github.com/crypticspaghetti/dotfiles.git \
        "$DOTFILES" >/dev/null
fi

source "$DOTFILES/zsh/.zshenv"
cd "$DOTFILES" && bash install.sh

