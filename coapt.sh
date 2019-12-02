#!/bin/bash
set -e
#
# coapt
#
# Tristan M. Chase
#
# A script meant to fit various apt-related scripts together.

# Dependencies

## System
sys_deps="aptitude perl findutils wget"

## coapt-specific (my scripts)
script_deps="coapt apt-snapshot"

# Create snapshot of installed packages.  apt-snapshot is a separate script.
apt-snapshot create

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

# Upgrade packages.
sudo aptitude upgrade

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
