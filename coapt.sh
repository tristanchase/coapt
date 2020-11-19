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
# * Replace echo with printf
# * Make autoremove an option
# * Modularize steps with functions

#-----------------------------------

# Initialize variables
#_temp="file.$$"

# List of temp files to clean up on exit (put last)
#_tempfiles=("${_temp}")

# Put main script here
function __main_script {

	## Create snapshot of installed packages (optional).  apt-snapshot is a separate script.
	#apt-snapshot create

	## Autoremove packages? (May require reboot)
	echo -n "Autoremove unused kernels and packages now? (May reqiure reboot) (y/N): "
	read _autoremove_yN
	function __autoremove__ {
		__lock_check
		sudo apt autoremove --purge
	}
	[[ "${_autoremove_yN}" =~ (y|Y) ]] && __autoremove__ || printf "%b\n" "Autoremove: skipped"


	echo ""
	echo "Updating..."

	## Update package lists.
	__lock_check
	sudo aptitude update

	## Hold packages specified in "${HOME}"/.local/share/coapt/hold
	_hold_dir=""${HOME}"/.local/share/coapt/hold"
	mkdir -p "${_hold_dir}"
	_held_packages=( $(basename $(printf "%b\n" "${_hold_dir}"/*) ) )


	if [[ -n "${_held_packages}" ]]; then
		echo "The following packages will be held at their current version:"
		aptitude versions $(printf "%b\n" "${_held_packages[@]}")
		echo ""
		__lock_check
		sudo aptitude -q=3 hold ${_held_packages}
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
	if [[ -n "${_held_packages}" ]]; then
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
