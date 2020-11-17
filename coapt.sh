#!/usr/bin/env bash

#-----------------------------------
# Usage Section

#//Usage: coapt [ {-d|--debug} ] [ {-h|--help} ]
#//Description: A script meant to fit various apt-related scripts together.
#//Examples: coapt; coapt --debug
#//Options:
#//	-d --debug	Enable debug mode
#//	-h --help	Display this help message

# Created: Long ago
# Tristan M. Chase <tristan.m.chase@gmail.com>

# Depends on:
# System: aptitude perl findutils wget
# Scripts: apt-snapshot (optional)

#-----------------------------------
# TODO Section
#
# * Update dependencies section

#-----------------------------------

# Initialize variables
#_temp="file.$$"

# List of temp files to clean up on exit (put last)
#_tempfiles=("${_temp}")

# Put main script here
function __main_script {

	# Config files
	_config_dir="${HOME}/.config/coapt"
	_held_packages_file="${_config_dir}/held-packages"

	# Check for config files
	if [[ ! -e ${_held_packages_file} ]]; then
		echo "Adding some missing config files..."
		mkdir -p ${_config_dir}
		touch ${_held_packages_file}
	fi

	# Create snapshot of installed packages (optional).  apt-snapshot is a separate script.
	#apt-snapshot create

	# Autoremove packages? (May require reboot)
	echo -n "Would you like to autoremove unused kernels and packages now? (May reqiure reboot) (y/N): "
	read _response

	case ${_response} in

		y|Y)
			sudo apt autoremove --purge
			;;

		*)
			#do nothing
			;;
	esac

	echo ""
	echo "Updating..."
	#sleep 2

	# Update package lists.
	sudo aptitude update

	# TODO Clean up this section; get rid of _held_packages_empty variable; base tests on _held_packages_file
	# TODO Add option to change the list of held packages with help
	# Check to see if ${HOME}/.config/held-packages is empty
	_held_packages_empty=0 # 0=not empty, 1=empty

	if [[ -s "${_held_packages_file}" ]]; then
		echo "The following packages will be held at their current version:"
		_held_packages="$(cat ${_held_packages_file})"
		#echo ${_held_packages}
		aptitude versions $(echo ${_held_packages})
		echo ""
	else
		_held_packages_empty=1
	fi

	# If empty=yes=1, skip hold

	# Else hold

	# Hold any packages at their current version?
	if [ ${_held_packages_empty} -ne 1 ]; then
		sudo aptitude hold ${_held_packages}
	fi

	# Upgrade packages.
	sudo aptitude upgrade

	# Give option to reboot system, if required.
	if [ -f /var/run/reboot-required ]; then
		cat /var/run/reboot-required
		echo -n "Would you like to reboot the system now? (y/N): "
		read _response

		case ${_response} in
			y|Y)
				__local_cleanup
				_seconds="5"
				while [ "${_seconds}" -gt 0 ]; do
					printf "%b" "Rebooting in "${_seconds}" seconds...\033[0K\r"
					sleep 1
					: $((_seconds--))
				done
				sudo reboot
				;;

			*)
				__info__ ""$(basename ${0}).$$": reboot deferred by user."
				exit 3 #reboot deferred
				;;
		esac

	fi

} #end __main_script

# Local functions (__local_function)

function __local_cleanup {
	#Release hold on any held packages.
	if [ ${_held_packages_empty} -ne 1 ]; then
		printf "%b\n"
		printf "%b\n" "Releasing hold on packages..."
		sudo aptitude unhold ${_held_packages} && printf "%b\n" "done."
	fi

	# Clean package cache.
	echo -n  "Cleaning cache..."
	sudo aptitude clean
	echo "done."
	printf "%b\n" "Cleanup complete."
	echo ""
}

# Source helper functions (__helper_function__)
if [[ -e ~/.functions.sh ]]; then
	source ~/.functions.sh
fi

# Low-tech logging function
__logger__

# Get some basic options
# TODO Make this more robust
if [[ "${1:-}" =~ (-d|--debug) ]]; then
	__debugger__
elif [[ "${1:-}" =~ (-h|--help) ]]; then
	__usage__
fi

# Bash settings
# Same as set -euE -o pipefail
#set -o errexit
set -o nounset
set -o errtrace
set -o pipefail
IFS=$'\n\t'

# Main Script Wrapper
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
	trap __traperr__ ERR
	trap __ctrl_c__ INT
	trap __cleanup__ EXIT

	__main_script


fi

exit 0
