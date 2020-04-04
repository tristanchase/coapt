#!/bin/bash
set -e
#
# coapt
#
# Tristan M. Chase
#
# A script meant to fit various apt-related scripts together.

## Config files
config_dir="$HOME/.config/coapt"
held_packages_file="$config_dir/held-packages"

# Check for config files
if [[ ! -e $held_packages_file ]]; then
	echo "Adding some missing config files..."
	mkdir -p $config_dir
	touch $held_packages_file
fi

# Dependencies

## System
sys_deps="aptitude perl findutils wget"

## coapt-specific (my scripts)
script_deps="coapt apt-snapshot"

# Create snapshot of installed packages.  apt-snapshot is a separate script.
sudo apt-snapshot create

# Autoremove packages? (May require reboot)
echo -n "Would you like to autoremove unused kernels and packages now? (May reqiure reboot) (y/N): "
read response

case $response in

	y|Y)
		sudo apt autoremove --purge
		;;

	*)
		#do nothing
		;;
esac

echo ""
echo -n "Updating..."
sleep 2

# Update package lists.
sudo aptitude update

# Check to see if $HOME/.config/held-packages is empty
held_packages_empty=0 # 0=not empty, 1=empty

if [[ -s "$held_packages_file" ]]; then
	echo "The following packages will be held at their current version:"
	held_packages="$(cat $held_packages_file)"
	echo $held_packages
	echo ""
else
	held_packages_empty=1
fi

# If empty=yes=1, skip hold

# Else hold

# Hold any packages at their current version?
if [ $held_packages_empty -ne 1 ]; then
	sudo aptitude hold $held_packages
fi

# Upgrade packages.
sudo aptitude upgrade

#Release hold on any held packages.
if [ $held_packages_empty -ne 1 ]; then
	sudo aptitude unhold $held_packages
fi

# Clean package cache.
echo ""
echo -n  "Cleaning cache..."
sudo aptitude clean
echo "done."
echo ""

# Give option to reboot system, if required.
if [ -f /var/run/reboot-required ]; then
	cat /var/run/reboot-required
	echo -n "Would you like to reboot the system now? (y/N): "
	read response

	case $response in
		y|Y)
			sudo reboot
			;;

		*)
			exit
			;;
	esac

fi

exit 0
