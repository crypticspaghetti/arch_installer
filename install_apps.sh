#!/usr/bin/env bash

name=$(cat /tmp/username)

apps_path=$(cat /tmp/apps.csv)
# Get the list of apps that I typically install on a new system
curl https://raw.githubusercontent.com/crypticspaghetti\
    /arch_install/master/apps.csv > $apps_path

dialog --title "Welcome!" \
    --msgbox "Welcome to the installation script for your apps and dotfiles!" \
    10 60

# Display the groupings of the apps to pick and choose from
apps=("essential" "Essentials" on
      "network" "Network" on
      "tools" "Nice tools to have (recommended)" on
      "tmux" "terminal multiplexer (tmux)" on
      "notifier" "Notification tools" on
      "git" "Git & related tools" on
      "i3" "i3 window manager" on
      "zsh" "The Z-Shell (zsh)" on
      "neovim" "Neovim" on
      "urxvt" "Unicode Rxvt" on
      "firefox" "Web browser (Firefox)" off)

dialog --checklist \
    "You can now choose what groups of applications you want to install. \n\n\
    You can select an option with SPACE and confirm your choices with ENTER." \
    0 0 0 \
    "${apps[@]}" 2> app_choices

# Take the group choices and grab all the app package names from the downloaded
# list that are in those groups
choices=$(cat app_choices) && rm app_choices
selection="^$(echo $choices) | sed -e 's/ /,|^/g),"
lines=$(grep -E "$selection" "$apps_path")
count=$(echo "$lines" | wc -l)
packages=$(echo "$lines" | awk -F, {'print $2'})

echo "$selection" "$lines" "$count" >> "/tmp/packages"

# Update the system before we attempt to install the apps
pacman -Syu --noconfirm
rm -f /tmp/aur_queue

dialog --title "Let's go!" --msgbox \
    "The system will now install everything you selected.\n\n\
    This will take some time.\n\n" \
    13 60

# Install the apps. Failed installs exiting as non-zero will be assumed to reside
# in AUR. If pacman fails the offending package will be output to a file for debugging. 
c=0
echo "$packages" | while read -r line; do
    c=$(( "$c" + 1 ))

    dialog --title "Applications Installation" --infobox \
        "Downloading and installing app $c out of $count: $line..." \
        8 70

    ((pacman --noconfirm --needed -S "$line" > /tmp/arch_install 2>&1) \
        || echo "$line" >> /tmp/aur_queue) \
        || echo "$line" >> /tmp/arch_install_failed

    if [ "$line" = "zsh" ]; then
        # Set zsh as default shell for the user
        chsh -s "$(which zsh)" "$name"
    fi

    if [ "$line" = "networkmanager" ]; then
        systemctl enable NetworkManager.service
    fi
done

# I know, I know. It's not being done with visudo. I am sorry!
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

curl https://raw.githubusercontent.com/crypticspaghetti\
    /arch_installer/master/install_user.sh > /tmp/install_user.sh

sudo -u "$name" sh /tmp/install_user.sh

