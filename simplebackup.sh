#!bin/bash

# simplebackup.sh. A simple script for backing up and restoring data from named
# directories.
# Copyright (C) 2025 Benjamin Cassell
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.


SIMPLEBACKUP_CONFIG="${HOME}/.simplebackupconfig"


# Write the configuration file out. Assumes that values have already been loaded.
sbup-writeconfig() {
	cat <<EOF > "${SIMPLEBACKUP_CONFIG}"
#!bin/bash
# Configuration values for the SimpleBackup script.

$(declare -p SIMPLEBACKUP_SOURCES)
$(declare -p SIMPLEBACKUP_DESTINATIONS)

EOF

	if [[ ${?} -ne 0 ]]; then
		echo "Error while writing SimpleBackup configuration file ${SIMPLEBACKUP_CONFIG}. Aborting."
		return 1;
	fi
}


# Create the user's configuration file. This must be run prior to using any
# other commands.
sbup-config() {
	# Warn the user if the config already exists (and give them the option to abort).
	if [[ -f "${SIMPLEBACKUP_CONFIG}" ]]; then
		local yes_no
		read -p "SimpleBackup configuration file ${SIMPLEBACKUP_CONFIG} already exists. Delete and overwrite [Y/N]? " -n 1 -r yes_no
		echo
		case "${yes_no}" in
			y|Y)
				echo "Deleting existing SimpleBackup configuration file ${SIMPLEBACKUP_CONFIG}."
				rm -f "${SIMPLEBACKUP_CONFIG}"
				if [[ ${?} -ne 0 ]]; then
					echo "Could not delete SimpleBackup configuration file ${SIMPLEBACKUP_CONFIG}. Aborting."
					return 1
				fi
				;;
			n|N)
				echo "Config cancelled by user. Aborting."
				return 0
				;;
			*)
				echo "Invalid option \"${yes_no}\". Please explicitly use [Y/N]. Aborting."
				return 1
				;;
		esac
	fi

	# Set empty variables and write out the config file.
	echo "Creating SimpleBackup configuration file ${SIMPLEBACKUP_CONFIG}."

	unset SIMPLEBACKUP_SOURCES
	unset SIMPLEBACKUP_DESTINATIONS

	declare -gA SIMPLEBACKUP_SOURCES=()
	declare -gA SIMPLEBACKUP_DESTINATIONS=()

	sbup-writeconfig
	if [[ ${?} -ne 0 ]]; then
		return 1;
	fi
}


# Attempts to load values from the SimpleBackup configuration.
sbup-loadconfig() {
	if [[ ! -f "${SIMPLEBACKUP_CONFIG}" ]]; then
		echo "No SimpleBackup configuration file ${SIMPLEBACKUP_CONFIG}. Please run sbup-config. Aborting."
		return 1;
	fi
	source "${SIMPLEBACKUP_CONFIG}"
	if [[ ${?} -ne 0 ]]; then
		echo "Error while sourcing SimpleBackup configuration file ${SIMPLEBACKUP_CONFIG}. Aborting."
		return 1;
	fi
}


# Show the configuration details for SimpleBackup.
sbup-showconfig() {
	sbup-loadconfig
	if [[ ${?} -ne 0 ]]; then
		return 1;
	fi
	cat "${SIMPLEBACKUP_CONFIG}"
}


# Add a key to the SimpleBackup configuration.
# Arguments:
#   $1 - The name of the key to add to the configuration.
sbup-add() {
	sbup-loadconfig
	if [[ ${?} -ne 0 ]]; then
		return 1;
	fi

	local add_key="${1}"

	# Abort if no key was provided.
	if [[ -z "${add_key// }" ]]; then
		echo "Key not provided. Aborting."
		return 1
	fi

	# Check if the user wants to overwrite an existing key.
	if [[ -v SIMPLEBACKUP_SOURCES["${add_key}"] || -v SIMPLEBACKUP_DESTINATIONS["${add_key}"] ]]; then
		local yes_no
		read -p "SimpleBackup configuration for key \"${add_key}\" already exists. Overwrite [Y/N]? " -n 1 -r yes_no
		echo
		case "${yes_no}" in
			y|Y)
				unset SIMPLEBACKUP_SOURCES["${add_key}"]
				unset SIMPLEBACKUP_DESTINATIONS["${add_key}"]
				;;
			n|N)
				echo "Adding key \"${add_key}\" cancelled by user. Aborting."
				return 0
				;;
			*)
				echo "Invalid option \"${yes_no}\". Please explicitly use [Y/N]. Aborting."
				return 1
				;;
		esac
	fi

	local add_source
	read -p "Enter the source directory for \"${add_key}\": " add_source
	
	# Abort if no source was provided.
	if [[ -z "${add_source// }" ]]; then
		echo "New source not provided. Aborting."
		return 1
	fi

	local add_destination
	read -p "Enter the destination directory for \"${add_key}\": " add_destination
	
	# Abort if no destination was provided.
	if [[ -z "${add_destination// }" ]]; then
		echo "New destination not provided. Aborting."
		return 1
	fi

    # Abort if the user tries to point the source and destination to the same place.
	# Note, we don't actually enforce that the source and destination exist at this point in time.
	if [[ "${add_source}" -ef "${add_destination}" || "${add_source}" == "${add_destination}" ]]; then
		echo "Source \"${add_source}\" and destination are identical. Aborting."
		return 1
	fi

	SIMPLEBACKUP_SOURCES["${add_key}"]="${add_source}"
	SIMPLEBACKUP_DESTINATIONS["${add_key}"]="${add_destination}"

	sbup-writeconfig
	if [[ ${?} -ne 0 ]]; then
		return 1;
	fi
	
	echo "Key \"${add_key}\" added to SimpleBackup configuration."
}


# Remove a key from the SimpleBackup configuration.
# Arguments:
#   $1 - The name of the key to remove from the configuration.
sbup-remove() {
	sbup-loadconfig
	if [[ ${?} -ne 0 ]]; then
		return 1;
	fi

	local remove_key="${1}"

	# Abort if no key was provided.
	if [[ -z "${remove_key// }" ]]; then
		echo "Key not provided. Aborting."
		return 1
	fi

	# If the provided key exists, remove it. Otherwise terminate.
	if [[ -v SIMPLEBACKUP_SOURCES["${remove_key}"] || -v SIMPLEBACKUP_DESTINATIONS["${remove_key}"] ]]; then
		unset SIMPLEBACKUP_SOURCES["${remove_key}"]
		unset SIMPLEBACKUP_DESTINATIONS["${remove_key}"]
		sbup-writeconfig
		if [[ ${?} -ne 0 ]]; then
			return 1;
		fi
		echo "Key \"${remove_key}\" removed from SimpleBackup configuration."
	else
		echo "Key \"${remove_key}\" not found in SimpleBackup configuration. Aborting."
		return 1
	fi
}


# Move files from the configured source to the configured destination.
# Arguments:
#   $1 - The key whose configuration will be used to save.
sbup-save() {
	sbup-loadconfig
	if [[ ${?} -ne 0 ]]; then
		return 1;
	fi

	local save_key="${1}"

	# Abort if no key was provided.
	if [[ -z "${save_key// }" ]]; then
		echo "Key not provided. Aborting."
		return 1
	fi

	# If the key doesn't exist then return.
	if [[ ! -v SIMPLEBACKUP_SOURCES["${save_key}"] || ! -v SIMPLEBACKUP_DESTINATIONS["${save_key}"] ]]; then
		echo "Key \"${save_key}\" not found in SimpleBackup configuration. Aborting."
		return 1
	fi

	local save_source="${SIMPLEBACKUP_SOURCES["${save_key}"]}"
	local save_destination="${SIMPLEBACKUP_DESTINATIONS["${save_key}"]}"

	# If either the source or destination does not exist at this point in time, abort.
	if [[ ! -d "${save_source}" ]]; then
		echo "Save source \"${save_source}\" is not a directory. Aborting."
		return 1
	fi
	if [[ ! -d "${save_destination}" ]]; then
		echo "Save destination \"${save_destination}\" is not a directory. Aborting."
		return 1
	fi

    # Abort if the source and destination point to the same place.
	if [[ "${save_source}" -ef "${save_destination}" ]]; then
		echo "Source \"${save_source}\" and destination are identical. Aborting."
		return 1
	fi

	echo "Saving files for configuration \"${save_key}\"."
	rsync -a --delete "${save_source}/" "${save_destination}/"
	if [[ "${?}" -ne "0" ]]; then
		echo "Saving files failed. Aborting."
		return 1
	fi
}


# Move files from the configured destination to the configured source.
# Arguments:
#   $1 - The key whose configuration will be used to load.
sbup-load() {
	sbup-loadconfig
	if [[ ${?} -ne 0 ]]; then
		return 1;
	fi

	local load_key="${1}"

	# Abort if no key was provided.
	if [[ -z "${load_key// }" ]]; then
		echo "Key not provided. Aborting."
		return 1
	fi

	# If the key doesn't exist then return.
	if [[ ! -v SIMPLEBACKUP_SOURCES["${load_key}"] || ! -v SIMPLEBACKUP_DESTINATIONS["${load_key}"] ]]; then
		echo "Key \"${load_key}\" not found in SimpleBackup configuration. Aborting."
		return 1
	fi

	local load_source="${SIMPLEBACKUP_SOURCES["${load_key}"]}"
	local load_destination="${SIMPLEBACKUP_DESTINATIONS["${load_key}"]}"

	# If either the source or destination does not exist at this point in time, abort.
	if [[ ! -d "${load_source}" ]]; then
		echo "Save source \"${load_source}\" is not a directory. Aborting."
		return 1
	fi
	if [[ ! -d "${load_destination}" ]]; then
		echo "Save destination \"${load_destination}\" is not a directory. Aborting."
		return 1
	fi

    # Abort if the source and destination point to the same place.
	if [[ "${load_source}" -ef "${load_destination}" ]]; then
		echo "Source \"${load_source}\" and destination are identical. Aborting."
		return 1
	fi

	echo "Loading files for configuration \"${load_key}\"."
	rsync -a --delete "${load_destination}/" "${load_source}/"
	if [[ "${?}" -ne "0" ]]; then
		echo "Loading files failed. Aborting."
		return 1
	fi
}

