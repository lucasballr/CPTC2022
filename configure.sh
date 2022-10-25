#!/bin/bash

set -e

# Add packages here as needed
APT_PACKAGES="python3 python3-pip ruby npm libc6:i386 libncurses5:i386 libstdc++6:i386 lib32z1 openjdk-11-jdk zsh powerline fonts-powerline zsh-theme-powerlevel9k zsh-syntax-highlighting command-not-found wireshark valgrind nmap gdb mlocate hashcat steghide foremost curl vim dirb"
SNAP_PACKAGES="code"
NPM_PACKAGES="tldr"
GEM_PACKAGES="one_gadget"
PIP_PACKAGES="pwntools pillow scapy xortool"

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

# usage: log(msg)
function log() {
	date=$(date +"%F %T")
	echo -e "${GREEN}[*] ${date} ${1}${ENDCOLOR}"
}

export DEBIAN_FRONTEND=noninteractive

log "Enabling 32-bit packages"
sudo dpkg --add-architecture i386

log "Updating system packages"
sudo -E apt update && sudo apt upgrade -y

# --install-suggests adds like an hour to install, no using for now
log "Installing new packages via apt"
for pkg in $APT_PACKAGES; do
	if dpkg --get-selections | grep -q "^$pkg[[:space:]]*install$" >/dev/null; then
		echo -e "${YELLOW}[APT] $pkg is already installed ${ENDCOLOR}"
	else
		if sudo -E apt-get install -y $pkg; then
			echo -e "${GREEN}[APT] Successfully installed $pkg ${ENDCOLOR}"
		else
			echo -e "${RED}[APT] Error installing $pkg ${ENDCOLOR}"
		fi
	fi
done

log "Installing new packages via snap"
for pkg in $SNAP_PACKAGES; do
	if snap list | grep -iq "^$pkg" >/dev/null; then
		echo -e "${YELLOW}[SNAP] $pkg is already installed ${ENDCOLOR}"
	else
		if sudo snap install --classic $pkg; then
			echo -e "${GREEN}[SNAP] Successfully installed $pkg ${ENDCOLOR}"
		else
			echo -e "${RED}[SNAP] Error installing $pkg ${ENDCOLOR}"
		fi
	fi
done

log "Installing new packages via npm"
for pkg in $NPM_PACKAGES; do
	if npm list -g | grep -iq $pkg@ >/dev/null; then
		echo -e "${YELLOW}[NPM] $pkg is already installed ${ENDCOLOR}"
	else
		if sudo npm install -g $pkg; then
			echo -e "${GREEN}[NPM] Successfully installed $pkg ${ENDCOLOR}"
		else
			echo -e "${RED}[NPM] Error installing $pkg ${ENDCOLOR}"
		fi
	fi
done

log "Installing gem packages"
for pkg in $GEM_PACKAGES; do
	if [ ! `gem list '^$pkg$' -i >/dev/null` ]; then
		echo -e "${YELLOW}[GEM] $pkg is already installed ${ENDCOLOR}"
	else
		if sudo gem install $pkg; then
			echo -e "${GREEN}[GEM] Successfully installed $pkg ${ENDCOLOR}"
		else
			echo -e "${RED}[GEM] Error installing $pkg ${ENDCOLOR}"
		fi
	fi
done

log "Upgrading pip"
pip3 install --upgrade pip

log "Creating virtualenv"
python3 -m pip install virtualenv
python3 -m virtualenv ~/pyenv
source ~/pyenv/bin/activate

log "Installing pip packages"
for pkg in $PIP_PACKAGES; do
	if pip freeze | grep -iq "^$pkg=" >/dev/null; then
		echo -e "${YELLOW}[PIP] $pkg is already installed ${ENDCOLOR}"
	else
		if python3 -m pip install $pkg; then
			echo -e "${GREEN}[PIP] Successfully installed $pkg ${ENDCOLOR}"
		else
			echo -e "${RED}[PIP] Error installing $pkg ${ENDCOLOR}"
		fi
	fi
done

#ZSH config
log "Configuring zsh"
sudo usermod -s /usr/bin/zsh $(whoami)
if [ ! `grep -q "source /usr/share/powerlevel9k/powerlevel9k.zsh-theme" ~/.zshrc` ]; then
	echo "source /usr/share/powerlevel9k/powerlevel9k.zsh-theme" >> ~/.zshrc
fi
if [ ! `grep -q "source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ~/.zshrc` ]; then
	echo "source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ~/.zshrc
fi
if [ ! `grep -q "source /etc/zsh_command_not_found" ~/.zshrc` ]; then
	echo "source /etc/zsh_command_not_found" >> ~/.zshrc
fi

# because python dependences are a pain in the ass
# Also adds to path
log "Adding venv to ~/.zshrc"
if [ ! `grep -q "source ~/pyenv/bin/activate" ~/.zshrc` ]; then
	echo "source ~/pyenv/bin/activate" >> ~/.zshrc
fi
if [ ! `grep -q "alias gdb=\"gdb -q\"" ~/.zshrc` ]; then
	echo "alias gdb=\"gdb -q\"" >> ~/.zshrc
fi
#echo -e "${GREEN}Successfully configured zsh ${ENDCOLOR}"


deactivate # leave virtualenv so pwndbg doesn't break


log "Configuring gdb"
if [ ! -d "$HOME/.pwndbg" ]; then
	git clone https://github.com/pwndbg/pwndbg ~/.pwndbg
	cd ~/.pwndbg
	chmod +x setup.sh
	./setup.sh
else
	echo -e "${YELLOW}[GDB] pwndbg is already installed ${ENDCOLOR}"
fi

log "Installing IDA Free 7.0"
if [ ! -d "/opt/idafree-7.0" ]; then
	cd $(mktemp -d)
	wget https://out7.hex-rays.com/files/idafree70_linux.run
	chmod +x idafree70_linux.run
	sudo ./idafree70_linux.run --mode unattended --installpassword ""
	sudo cp ~/setup/idapro.desktop /usr/share/applications
else
	echo -e "${YELLOW}[IDA] IDA Free 7.0 is already installed ${ENDCOLOR}"
fi

log "Installing Ghidra 10.1.2"
if [ ! -d "/opt/ghidra" ]; then
	wget https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_10.1.2_build/ghidra_10.1.2_PUBLIC_20220125.zip -O ~/Downloads/ghidra.zip
	sudo unzip ~/Downloads/ghidra.zip -d /opt/
	sudo mv /opt/ghidra_10.1.2_PUBLIC /opt/ghidra
	sudo cp ~/setup/ghidra.desktop /usr/share/applications
	sudo cp ~/setup/ghidra.png /opt/ghidra/support/ghidra.png
	sudo chown $(whoami): -R /opt/ghidra
	log "First Run of Ghidra to create ghidra home files"
	echo 'Running Ghidra. Please reach the "Ghidra: NO ACTIVE PROJECT" screen, then close Ghidra'
	/opt/ghidra/ghidraRun
	read -p "Press enter once you have done this"
else
	echo -e "${YELLOW}[GHI] Ghidra 10.1.2 is already installed ${ENDCOLOR}"
fi

log "Terminating Ghidra if Running"
pkill -f ghidra || true

log "Applying Ghidra Dark Theme"
if [ ! -f "/opt/ghidra/flatlaf-0.43.jar" ]; then
	cd $(mktemp -d)
	git clone https://github.com/zackelia/ghidra-dark.git ghidra_dark
	cd ghidra_dark
	python3 install.py --path /opt/ghidra/
else
	echo -e "${YELLOW}[GHI] Ghidra Dark Theme is already installed ${ENDCOLOR}"
fi

log "Cloning OSUSEC Scripts"
if [ ! -d "~/osusec_scripts" ]; then
	git clone git@gitlab.com:osusec/ctf-team/ctf-scripts.git ~/osusec_scripts
	log "Scripts cloned."
else
	echo -e "${YELLOW}[SCR] Scripts are already cloned, very cool! ${ENDCOLOR}"
fi

log "Cleaning up, installing any further udpates"
sudo apt update -y
sudo apt dist-upgrade -y
sudo apt autoremove -y

cd ~

log $'\n'"Configuration finished, please reboot your VM"
log $'\n'"P.S. HONK THE PLANET!"

log "Prompting for Reboot"
read -p "Press enter to reboot your VM to apply changes"
sudo reboot
