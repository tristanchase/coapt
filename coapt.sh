#!/bin/bash
#
# coapt
#
# Tristan M. Chase
#
# A script meant to fit various other apt-related scripts together.

# Dependencies

## System
sys_deps="perl findutils wget" 

## coapt-specific
script_deps="coapt apt-snapshot"

# Create snapshot of installed packages.  apt-snapshot is a separate script.
apt-snapshot create

# Autoremove packages? (May require reboot)
# TODO Maybe do a dry run with sudo apt-get autoremove -s or something
echo -n "Would you like to autoremove unused kernels and packages now? (May reqiure reboot) (y/N/): "; read response

	case $response in
#		?)
#			sudo apt-get autoremove --dry-run
#			;;
#
		y|Y)
			sudo apt-get autoremove --purge
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

## Clean up older snapshots. benchmark is a separate script.
## TODO Add option to benchmark certain snapshots.
#  echo -n "Deleting old snapshots..."
## Moves files modified more than 30 days ago to Trash, but as root.  chown to $USER?
#  sudo find /var/cache/apt/snapshots/* -mtime +30 -exec mv {} $HOME/.local/share/Trash/files \;
## Removes files modified more than 30 days ago forever.
#  sudo find /var/cache/apt/snapshots/* -mtime +30 -exec rm {} \;
#  echo "done."
#  echo ""

# Give option to reboot system, if required.
if [ -f /var/run/reboot-required ]; then
	cat /var/run/reboot-required
	echo -n "Would you like to reboot the system now? (y/N): "; read response

	case $response in
		y|Y)
			sudo reboot
			;;

		*)
			exit
			;;
	esac

fi
