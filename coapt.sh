#!/usr/bin/env bash
set -euo pipefail
set -o errtrace
#set -x
IFS=$'\n\t'

#-----------------------------------

#/ Usage: coapt [--help]
#/ Description: A script meant to fit various apt-related scripts together.
#/ Examples:
#/ Options:
#/   --help: Display this help message

# Created: Long ago
# Tristan M. Chase <tristan.m.chase@gmail.com>

# Depends on:
# System: aptitude perl findutils wget
# Scripts: apt-snapshot (optional)

#-----------------------------------
# Low-tech help option

usage() { grep '^#/' "$0" | cut -c4- ; exit 0 ; }
expr "$*" : ".*--help" > /dev/null && usage

#-----------------------------------
# Low-tech logging function

readonly LOG_FILE="/tmp/$(basename "$0").log"
info()    { echo "[INFO]    $*" | tee -a "$LOG_FILE" >&2 ; }
warning() { echo "[WARNING] $*" | tee -a "$LOG_FILE" >&2 ; }
error()   { echo "[ERROR]   $*" | tee -a "$LOG_FILE" >&2 ; }
fatal()   { echo "[FATAL]   $*" | tee -a "$LOG_FILE" >&2 ; exit 1 ; }

#-----------------------------------
# Trap functions

traperr() {
	info "ERROR: ${BASH_SOURCE[1]}.$$ at line ${BASH_LINENO[0]}"
}

ctrl_c(){
	exit 2
}

cleanup() {
	case "$?" in
		0) # exit 0; success!
			#do nothing
			;;
		2) # exit 2; user termination
			info ""$(basename $0).$$": script terminated by user."
			;;
		3) # exit 3; reboot deferred
			info ""$(basename $0).$$": reboot deferred by user."
			;;
		*) # any other exit number; indicates an error in the script
			#clean up stray files
			#fatal ""$(basename $0)": [error message here]"
			;;
	esac
}

#-----------------------------------
# Main script wrapper

if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
	trap traperr ERR
	trap ctrl_c INT
	trap cleanup EXIT
	#-----------------------------------
	# Main Script

	# Config files
	config_dir="$HOME/.config/coapt"
	held_packages_file="$config_dir/held-packages"

	# Check for config files
	if [[ ! -e $held_packages_file ]]; then
		echo "Adding some missing config files..."
		mkdir -p $config_dir
		touch $held_packages_file
	fi

	# Create snapshot of installed packages (optional).  apt-snapshot is a separate script.
	#apt-snapshot create

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
	echo "Updating..."
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
				exit 3
				;;
		esac

	fi

	# End Main Script
	#-----------------------------------

fi

# End of main script wrapper
#-----------------------------------

exit 0
