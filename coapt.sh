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

	## Config files
	_config_dir="${HOME}/.config/coapt"
	_held_packages_file="${_config_dir}/held-packages"

	## Check for config files
	if [[ ! -e ${_held_packages_file} ]]; then
		echo "Adding some missing config files..."
		mkdir -p ${_config_dir}
		touch ${_held_packages_file}
		__info__ "Added file "${_held_packages_file}"."
	fi

	## Create snapshot of installed packages (optional).  apt-snapshot is a separate script.
	#apt-snapshot create

	## Autoremove packages? (May require reboot)
	echo -n "Would you like to autoremove unused kernels and packages now? (May reqiure reboot) (y/N): "
	read _response

	case ${_response} in

		y|Y)
			__lock_check
			sudo apt autoremove --purge
			;;

		*)
			#do nothing
			;;
	esac

	echo ""
	echo "Updating..."

	## Update package lists.
	__lock_check
	sudo aptitude update

	## Hold packages specified in "${HOME}"/.local/share/coapt/hold
	_hold_dir=""${HOME}"/.local/share/coapt/hold"
	mkdir -p "${_hold_dir}"
	_held_packages=( $(basename $(printf "%b\n" "${_hold_dir}"/*) ) )

	# TODO Clean up this section; get rid of _held_packages_empty variable; base tests on _held_packages_file
	# TODO Add option to change the list of held packages with help
	# Check to see if ${HOME}/.config/held-packages is empty
	_held_packages_empty=0 # 0=not empty, 1=empty

	if [[ -s "${_held_packages_file}" ]]; then
		echo "The following packages will be held at their current version:"
		#_held_packages="$(cat ${_held_packages_file})"
		aptitude versions $(printf "%b\n" "${_held_packages[@]}")
		echo ""
	else
		_held_packages_empty=1
	fi

	# If empty=yes=1, skip hold

	# Else hold

	# Hold any packages at their current version?
	if [ ${_held_packages_empty} -ne 1 ]; then
		__lock_check
		sudo aptitude hold ${_held_packages}
	fi

	## Upgrade packages.
	__lock_check
	sudo aptitude upgrade

	## Give option to reboot system, if required.
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

# Local functions

function __local_cleanup {
	## Release hold on any held packages.
	if [ ${_held_packages_empty} -ne 1 ]; then
		printf "%b\n"
		printf "%b" "Releasing hold on packages..."
		__lock_check
		sudo aptitude -q=3 unhold ${_held_packages} && printf "%b\n" "done."
	fi

	## Clean package cache.
	echo -n  "Cleaning cache..."
	__lock_check
	sudo aptitude clean
	echo "done."
	printf "%b\n" "Cleanup complete."
	echo ""
}

function __lock_check {
	## Check if any other processes have a lock on the package management system.

	# Only set this if your $SHELL is bash
	if [[ $SHELL =~ (bash) ]]; then
		shopt -s globstar
	fi

	## Dynamically find related lockfiles.
	_lockfiles=( "$(printf "%b\n" /var/** | grep -E '/(daily_)?lock(-frontend)?'$)" )
	i=0
	tput sc
	#while sudo fuser /var/lib/dpkg/{lock,lock-frontend} >/dev/null 2>&1 ; do
	while sudo fuser ${_lockfiles}  >/dev/null 2>&1; do
		case $(($i % 4)) in
			0 ) j="-" ;;
			1 ) j="\\" ;;
			2 ) j="|" ;;
			3 ) j="/" ;;
		esac
		tput rc
		echo -en "\r[$j] Waiting for other software managers to finish..."
		sleep 0.5
		((i=i+1))
	done
}

# Source helper functions
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
#set -o errexit # aptitude upgrade exits with 1 if aborted
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
