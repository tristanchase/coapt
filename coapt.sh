#!/usr/bin/env bash

# Low-tech debug mode
if [[ "${1:-}" =~ (-d|--debug) ]]; then
	set -x
	_debug_file=""${HOME}"/tmp/$(basename "${0}")-debug.$$"
	exec > >(tee "${_debug_file:-}") 2>&1
	shift
fi

# Same as set -euE -o pipefail
set -o errexit
set -o nounset
set -o errtrace
set -o pipefail
IFS=$'\n\t'

#-----------------------------------

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
# Low-tech help option

function __usage() { grep '^#/' "${0}" | cut -c4- ; exit 0 ; }
expr "$*" : ".*-h\|--help" > /dev/null && __usage

#-----------------------------------
# Low-tech logging function

readonly LOG_FILE=""${HOME}"/tmp/$(basename "${0}").log"
function __info()    { echo "[INFO]    $*" | tee -a "${LOG_FILE}" >&2 ; }
function __warning() { echo "[WARNING] $*" | tee -a "${LOG_FILE}" >&2 ; }
function __error()   { echo "[ERROR]   $*" | tee -a "${LOG_FILE}" >&2 ; }
function __fatal()   { echo "[FATAL]   $*" | tee -a "${LOG_FILE}" >&2 ; exit 1 ; }

#-----------------------------------
# Trap functions

function __traperr() {
	__error "${FUNCNAME[1]}: ${BASH_COMMAND}: $?: ${BASH_SOURCE[1]}.$$ at line ${BASH_LINENO[0]}"
}

function __ctrl_c(){
	exit 2
}

function __cleanup() {
	case "$?" in
		0) # exit 0; success!
			#do nothing
			;;
		2) # exit 2; user termination
			__info ""$(basename ${0}).$$": script terminated by user."
			;;
		3) # exit 3; reboot deferred
			__info ""$(basename ${0}).$$": reboot deferred by user."
			;;
		*) # any other exit number; indicates an error in the script
			#clean up stray files
			#__fatal ""$(basename ${0}).$$": [error message here]"
			;;
	esac

	if [[ -n "${_debug_file:-}" ]]; then
		echo "Debug file is: "${_debug_file:-}""
	fi
}

#-----------------------------------
# Main script wrapper

if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
	trap __traperr ERR
	trap __ctrl_c INT
	trap __cleanup EXIT
	#-----------------------------------
	# Main Script

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
	sleep 2

	# Update package lists.
	sudo aptitude update

	# TODO Clean up this section
	# TODO Add option to change the list of held packages with help
	# Check to see if ${HOME}/.config/held-packages is empty
	_held_packages_empty=0 # 0=not empty, 1=empty

	if [[ -s "${_held_packages_file}" ]]; then
		echo "The following packages will be held at their current version:"
		_held_packages="$(cat ${_held_packages_file})"
		echo ${_held_packages}
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

	#Release hold on any held packages.
	if [ ${_held_packages_empty} -ne 1 ]; then
		sudo aptitude unhold ${_held_packages}
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
		read _response

		case ${_response} in
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

# TODO (bottom up)
#
# * Update dependencies section
