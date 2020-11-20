#!/usr/bin/env bash

#-----------------------------------
# Usage Section

#//Usage: coapt [ {-d|--debug} ] [ {-h|--help} | {-a|--autoremove} ]
#//Description: A script meant to fit various apt-related scripts together.
#//Examples: coapt; coapt --debug; coapt --autoremove
#//Options:
#//	-a --autoremove	Autoremove unused packages
#//	-d --debug	Enable debug mode
#//	-h --help	Display this help message
#**	   --holds	Manage held packages
#**	-s --snapshot	Create a snapshot of installed packages

# Created: Long ago
# Tristan M. Chase <tristan.m.chase@gmail.com>

# Depends on:
# System: aptitude perl findutils wget
# Scripts: apt-snapshot (optional)

#-----------------------------------
# TODO Section
#
# * Make snapshot an option
#   * Rework snapshot section
#     * Get rid of apt-snapshot
#       * coapt.sh
#       * install.sh
#     * Remove perl from system deps
#       * coapt.sh
#       * install.sh
#     * Use dpkg --list
#   * Update usage section
#   * Update README.adoc
# * Make hold management an option
#   * Update usage section
#   * Update README.adoc
# * Update dependencies section

# DONE
# + Make autoremove an option
#   + Update usage section
#   + Update README.adoc

#-----------------------------------

# Initialize variables
#_temp="file.$$"

# List of temp files to clean up on exit (put last)
#_tempfiles=("${_temp}")

# Put main script here
function __main_script {

	_share_dir=""${HOME}"/.local/share/coapt"

	## Create snapshot of installed packages (optional).  apt-snapshot is a separate script.

	#apt-snapshot create

	## Autoremove packages? (May require reboot)

	## Update package lists.

	function __update__ {
	printf "%b\n" "Updating package lists..."
	__lock_check__
	sudo aptitude update
	}

	__update__

	## Hold packages specified in "${HOME}"/.local/share/coapt/hold

	_hold_dir=""${_share_dir}"/hold"
	mkdir -p "${_hold_dir}"
	_held_packages=( $(basename -a $(printf "%b\n" "${_hold_dir}"/*) ) )

	__hold_packages__

	## Upgrade packages.

	function __upgrade__ {
		__lock_check__
		sudo aptitude upgrade
	}

	__upgrade__

	## Release hold on any held packages (in __local_cleanup__).

	## Clean package cache (in __local_cleanup__).

	## Give option to reboot system, if required.

	function __reboot__ {
		:
	}

	if [ -f /var/run/reboot-required ]; then
		cat /var/run/reboot-required
		printf "%b" -n "Would you like to reboot the system now? (y/N): "
		read _response

		case ${_response} in
			y|Y)
				__local_cleanup__
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

function __autoremove__ {
	printf "%b\n" "Autoremoving unused packages..."
	__lock_check__
	sudo apt autoremove --purge
}

function __clean_cache__ {
	printf "%b" "Cleaning cache..."
	__lock_check__
	sudo aptitude clean
	printf "%b\n" "done."
	printf "%b\n" "Cleanup complete."
	printf "%b\n"
}

function __hold_packages__ {
	if [[ -n"${_held_packages}" ]]; then
		printf "%b\n" "The following packages will be held at their current version:"
		aptitude versions $(printf "%b\n" "${_held_packages[@]}")
		printf "%b\n"
		__lock_check__
		sudo aptitude -q=3 hold ${_held_packages}
	fi
}

function __local_cleanup__ {
	__unhold_packages__
	__clean_cache__
}

## Check if any other processes have a lock on the package management system.

# Dynamically find related lockfiles.
_lockfiles=( "$(printf "%b\n" /var/** | grep -E '/(daily_)?lock(-frontend)?'$)" )

function __lock_check__ {

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
		printf "%b" "\r[$j] Waiting for other software managers to finish..."
		sleep 0.5
		((i=i+1))
	done
}

function __snapshot__ {
	_snapshot_dir=""${_share_dir}"/snapshots"
	_snapshot_file=""${_snapshot_dir}"/$(date -Iseconds)-coapt.$$"
	mkdir -p "${_snapshot_dir}"
	dpkg --list > "${_snapshot_file}"
}

function __unhold_packages__ {
	if [[ -n "${_held_packages}" ]]; then
		printf "%b\n"
		printf "%b" "Releasing hold on packages..."
		__lock_check__
		sudo aptitude -q=3 unhold ${_held_packages} && printf "%b\n" "done."
	fi
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
elif [[ "${1:-}" =~ (-a|--autoremove) ]]; then
	__autoremove__
fi

# Bash settings
# Same as set -euE -o pipefail
#set -o errexit # aptitude upgrade exits with 1 if aborted
set -o nounset
set -o errtrace
set -o pipefail
IFS=$'\n\t'

# Only set this if your $SHELL is bash
if [[ $SHELL =~ (bash) ]]; then
	shopt -s globstar
fi


# Main Script Wrapper
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
	trap __traperr__ ERR
	trap __ctrl_c__ INT
	trap __cleanup__ EXIT

	__main_script


fi

exit 0
