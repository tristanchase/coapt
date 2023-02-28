#!/usr/bin/env bash

#-----------------------------------
# Usage Section

#//Usage: coapt [ {-d|--debug} ] [ {-h|--help} | {-s|--snapshot} | {-a|--autoremove} | {-i|--ignore-hold} ]
#//Description: coapt is a collection of apt-related scripts arranged in a logical order (see README.adoc).
#//Examples: coapt; coapt --debug; coapt --autoremove
#//Options:
#//	-a --autoremove		Autoremove unused packages
#//	-d --debug		Enable debug mode
#//	-h --help		Display this help message
#**	   --holds		Manage held packages
#//	-i --ignore-hold	Ignore holds on packages
#//	-s --snapshot		Create a snapshot of installed packages and exit

# Created: Long ago
# Tristan M. Chase <tristan.m.chase@gmail.com>

# Depends on:
# System: aptitude findutils wget

#-----------------------------------
# TODO Section
#
# * Skip __local_cleanup__ on ^C
# * Alert user if program exits after __hold_packages__ but before __unhold_packages__
# * Make hold management an option
#   * Update usage section
#   * Update README.adoc
# * Update dependencies section

# DONE
# + Add --ignore-hold option
# + Edit __clean_cache__ function
# + Edit __unhold_packages__ function
#   + Warn if error

#-----------------------------------

# Initialize variables
#_temp="file.$$"

# List of temp files to clean up on exit (put last)
#_tempfiles=("${_temp:-}")

# Put main script here
function __main_script {

	# Define directories.
	_share_dir=${HOME}/.local/share/coapt
	_error_dir=""${_share_dir:-}"/errors" && mkdir -p "${_error_dir:-}"
	_hold_dir=""${_share_dir:-}"/hold" && mkdir -p "${_hold_dir}"
	_log_dir=""${_share_dir:-}"/log" && mkdir -p "${_log_dir}"
	_snapshot_dir=""${_share_dir:-}"/snapshots" && mkdir -p "${_snapshot_dir:-}"

	# Define log file.
	_log_file=""${_log_dir:-}"/"$(date -Iseconds)-coapt.log.$$"" && touch "${_log_file}"
	__start_logging__

	# Define error files.
	_purge_error_file=""${_error_dir}"/purge-errors"

	# Hold packages specified in ${HOME}/.local/share/coapt/hold/held-packages
	_held_packages_file="${_hold_dir:-}/held-packages" && touch "${_held_packages_file}"
	_held_packages="$(sort -u ${_held_packages_file})"

	# Dynamically find related lockfiles.
	_lockfiles=( "$(printf "%b\n" /var/** | grep -E '/(daily_)?lock(-frontend)?'$)" )

	# Create snapshot of installed packages and exit (optional).
	if [[ "${_snapshot_yN:-}" =~ (y) ]]; then
		__snapshot__
	fi

	# Autoremove packages, resolve purge errors, and exit or reboot if necessary (optional).
	if [[ "${_autoremove_yN:-}" =~ (y) ]]; then
		__autoremove__
		__resolve_purge_errors__
		__reboot_option__
		exit 0
	fi

	# Update package lists.
	__update_packages__

	# Upgrade packages.
	__upgrade_packages__

	# Clean package cache.
	__clean_cache__

	# Give option to reboot system, if required.
	__reboot_option__

} #end __main_script

# Local functions

function __autoremove__ {
	sudo printf "%b\n" "Autoremoving unused packages..."
	__lock_check__
	sudo apt-get autoremove --purge
}

function __clean_cache__ {
	printf "%b" "Cleaning cache..."
	__lock_check__
	sudo aptitude clean && printf "%b\n" "done." || printf "%b\n" "Error! Unable to clean cache."
	printf "%b\n"
}

function __hold_packages__ {
	if [[ -n "${_held_packages:-}" ]]; then
		printf "%b\n" "The following packages will be held at their current version:"
		aptitude versions $(printf "%b\n" "${_held_packages[@]:-}")
		printf "%b\n"
		__lock_check__
		sudo aptitude -q=3 hold ${_held_packages:-}
	fi
}

function __local_cleanup__ {
	:
}

# Check if any other processes have a lock on the package management system.

# Dynamically find related lockfiles.
#_lockfiles=( "$(printf "%b\n" /var/** | grep -E '/(daily_)?lock(-frontend)?'$)" )

function __lock_check__ {
	if sudo fuser ${_lockfiles} ; then
		printf "%b" "There is a lock on the package management system: wait or quit? (w/Q): "
		read _wQ
	else
		return 0
	fi

	if [[ "${_wQ:-}" = "w" ]]; then
		i=0
		tput sc
		while sudo fuser ${_lockfiles}  >/dev/null 2>&1; do
			case $(($i % 4)) in
				0 ) j="- " ;;
				1 ) j="\\ " ;;
				2 ) j="| " ;;
				3 ) j="/ " ;;
			esac
			tput rc
			printf "%b" "\r"$j"Waiting for other software managers to finish..."
			sleep 0.5
			((i=i+1))
		done
		printf "%b\n" "done."
		printf "%b\n"  "Lock has been released."
	else
		exit 4
	fi
}

function __reboot_option__ {
	if [ -f /var/run/reboot-required ]; then
		cat /var/run/reboot-required
		printf "%b" "Would you like to reboot the system now? (y/N): "
		read _response

		case ${_response:-} in
			y|Y)
				_seconds="5"
				while [ "${_seconds:-}" -gt -1 ]; do
					printf "%b" "Rebooting in "${_seconds:-}" seconds...\033[0K\r"
					sleep 1
					: $((_seconds--))
				done
				printf "%b\n"
				printf "%b\n" "Reboot!"
				sudo reboot
				;;

			*)
				__info__ ""$(basename ${0}).$$": reboot deferred by user."
				exit 3 #reboot deferred
				;;
		esac

	fi
}

function __resolve_purge_errors__ {
	grep -E 'not empty|failed|warning' "${_log_file}" > "${_purge_error_file}"
	if [[ -s "${_purge_error_file}" ]]; then
		printf "%b\n" ""
		printf "%b\n" "The following errors occured while purging packages:"
		cat "${_purge_error_file}"
	fi
}

function __start_logging__ {
	exec > >(tee "${_log_file:-}") 2>&1
}


function __snapshot__ {
	_snapshot_file=""${_snapshot_dir:-}"/$(date -Iseconds)-coapt.$$"
	printf "%b" "Creating snapshot..."
	dpkg --list > "${_snapshot_file:-}" && printf "%b\n" "done."
	printf "%b\n" "Snapshots are located in "${_snapshot_dir:-}"."
	exit 0
}

function __unhold_packages__ {
	if [[ -n "${_held_packages:-}" ]]; then
		printf "%b\n"
		printf "%b" "Releasing hold on packages..."
		__lock_check__
		sudo aptitude -q=3 unhold ${_held_packages:-} && printf "%b\n" "done." \
			|| printf "%b\n" "Error! Unable to release hold on packages."
	fi
}

function __update_packages__ {
	sudo printf "%b\n" "Updating package lists..."
	__lock_check__
	sudo aptitude update
}

function __upgrade_packages__ {
	__lock_check__
if [[ "${_ignore_hold_yN:-}" =~ (y) ]]; then
	sudo apt-get upgrade --ignore-hold
else
	__hold_packages__
	sudo aptitude upgrade
	__unhold_packages__
fi
}

# Source helper functions
for _helper_file in functions colors git-prompt; do
	if [[ ! -e ${HOME}/."${_helper_file}".sh ]]; then
		printf "%b\n" "Downloading missing script file "${_helper_file}".sh..."
		sleep 1
		wget -nv -P ${HOME} https://raw.githubusercontent.com/tristanchase/dotfiles/main/"${_helper_file}".sh
		mv ${HOME}/"${_helper_file}".sh ${HOME}/."${_helper_file}".sh
	fi
done

source ${HOME}/.functions.sh

# Get some basic options
# TODO Make this more robust
if [[ "${1:-}" =~ (-d|--debug) ]]; then
	__debugger__
elif [[ "${1:-}" =~ (-h|--help) ]]; then
	__usage__
elif [[ "${1:-}" =~ (-s|--snapshot) ]]; then
	_snapshot_yN="y"
elif [[ "${1:-}" =~ (-a|--autoremove) ]]; then
	_autoremove_yN="y"
elif [[ "${1:-}" =~ (-i|--ignore-hold) ]]; then
	_ignore_hold_yN="y"
fi

# Bash settings
# Same as set -euE -o pipefail
#set -o errexit # aptitude upgrade exits with 1 if aborted
#set -o nounset
#set -o errtrace
#set -o pipefail
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
