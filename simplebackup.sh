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


SIMPLEBACKUP_CONFIG_DIR="${HOME}/.simplebackup"


# Create the simple backup configuration directory. This must be run prior to
# executing other commands.
sbup-config() {
	# Warn the user if the configuration directory already exists (and give them the option to abort).
	if [[ -e "${SIMPLEBACKUP_CONFIG_DIR}" ]]; then
		local yes_no
		read -p "SimpleBackup configuration directory \"${SIMPLEBACKUP_CONFIG_DIR}\" already exists. Delete and overwrite [Y/N]? " -n 1 -r yes_no
		echo
		case "${yes_no}" in
			y|Y)
				echo "Deleting existing configuration directory."
				rm -rf "${SIMPLEBACKUP_CONFIG_DIR}"
				if [[ ${?} -ne 0 ]]; then
					echo "Could not delete configuration directory. Aborting."
					return 1
				fi
				;;
			n|N)
				echo "Configuration cancelled by user. Aborting."
				return 1
				;;
			*)
				echo "Invalid option \"${yes_no}\". Please explicitly use [Y/N]. Aborting."
				return 1
				;;
		esac
	fi

	# Create the directory.
	echo "Creating SimpleBackup configuration directory \"${SIMPLEBACKUP_CONFIG_DIR}\"."
	mkdir -p "${SIMPLEBACKUP_CONFIG_DIR}"
	if [[ ${?} -ne 0 ]]; then
		echo "Error creating configuration directory. Aborting."
		return 1;
	fi
}


# Write a configuration file for a specified key. Assumes that values have
# already been loaded for the following constants: SIMPLEBACKUP_SOURCE,
# SIMPLEBACKUP_DESTINATION, SIMPLEBACKUP_FILTERS.
#
# SIMPLEBACKUP_SOURCE is a path to the source folder that will be copied from
# during save and copied to during load.
#
# SIMPLEBACKUP_DESTINATION is a path to the destination folder that will be
# copied to during save and copied from during load.
#
# SIMPLEBACKUP_FILTERS are a list of rsync-patterned exclude filters that will
# be applied to the copy. It will prevent copying / deleting any files matching
# these filter patterns. This is stored as an associative array where each key
# is one of the filters (with a blank corresponding value).
#
# Arguments:
#   $1 - The key of the configuration to write out.
sbup-writeconfig() {
	# Get the key, abort if not provided.
	local key="${1}"
	if [[ -z "${key// }" ]]; then
		echo "Key not provided. Aborting."
		return 1
	fi
	local config_file="${SIMPLEBACKUP_CONFIG_DIR}/${key}"
	
	cat <<EOF > "${config_file}"
#!bin/bash
# Configuration values for the SimpleBackup script.

$(declare -p SIMPLEBACKUP_SOURCE)
$(declare -p SIMPLEBACKUP_DESTINATION)
$(declare -p SIMPLEBACKUP_FILTERS)

EOF

	if [[ ${?} -ne 0 ]]; then
		echo "Error while writing configuration file ${config_file}. Aborting."
		return 1;
	fi
}


# Load the a configuration of a specified key.
# Arguments:
#   $1 - The key of the configuration to load.
sbup-loadconfig() {
	# Get the key, abort if not provided.
	local key="${1}"
	if [[ -z "${key// }" ]]; then
		echo "Key not provided. Aborting."
		return 1
	fi
	local config_file="${SIMPLEBACKUP_CONFIG_DIR}/${key}"

	if [[ ! -d "${SIMPLEBACKUP_CONFIG_DIR}" ]]; then
		echo "SimpleBackup configuration directory \"${SIMPLEBACKUP_CONFIG_DIR}\" not found. Please run sbup-config. Aborting."
		return 1;
	fi
	if [[ ! -f "${config_file}" ]]; then
		echo "SimpleBackup configuration file \"${config_file}\" not found. Aborting."
		return 1;
	fi

	source "${config_file}"
	if [[ ${?} -ne 0 ]]; then
		echo "Error while sourcing SimpleBackup configuration file \"${config_file}\". Aborting."
		return 1;
	fi
	if [[ -z "${SIMPLEBACKUP_SOURCE// }" ]]; then
		echo "No source found for key \"${key}\". Aborting."
		return 1;
	fi
}


# Show the configuration of a specified key.
# Arguments:
#   $1 - The key of the configuration to show.
sbup-showconfig() {
	# Get the key, abort if not provided.
	local key="${1}"
	if [[ -z "${key// }" ]]; then
		echo "Key not provided. Aborting."
		return 1
	fi

	local config_file="${SIMPLEBACKUP_CONFIG_DIR}/${key}"
	if [[ ! -d "${SIMPLEBACKUP_CONFIG_DIR}" ]]; then
		echo "SimpleBackup configuration directory \"${SIMPLEBACKUP_CONFIG_DIR}\" not found. Please run sbup-config. Aborting."
		return 1;
	fi
	if [[ ! -f "${config_file}" ]]; then
		echo "SimpleBackup configuration file \"${config_file}\" not found. Aborting."
		return 1;
	fi

	cat "${config_file}"
}


# Add a key to the SimpleBackup configuration.
# Arguments:
#   $1 - The name of the key to add to the configuration.
#   $2 - The source directory to use for the key.
#   $3 - The destination directory to use for the key.
sbup-add() {
	# Get the key, abort if not provided.
	local key="${1}"
	if [[ -z "${key// }" ]]; then
		echo "Key not provided. Aborting."
		return 1
	fi
	local config_file="${SIMPLEBACKUP_CONFIG_DIR}/${key}"

	local source="${2}"
	if [[ -z "${source// }" ]]; then
		echo "Source not provided. Aborting."
		return 1
	fi
	
	local destination="${3}"
	if [[ -z "${destination// }" ]]; then
		echo "Destination not provided. Aborting."
		return 1
	fi

	if [[ ! -d "${SIMPLEBACKUP_CONFIG_DIR}" ]]; then
		echo "SimpleBackup configuration directory \"${SIMPLEBACKUP_CONFIG_DIR}\" not found. Please run sbup-config. Aborting."
		return 1;
	fi
    
	# Abort if the user tries to point the source and destination to the same place.
	# Note, we don't actually enforce that the source and destination exist at this point in time.
	if [[ "${source}" -ef "${destination}" || "${source}" == "${destination}" ]]; then
		echo "Source \"${source}\" and destination are identical. Aborting."
		return 1
	fi

	# Check if the user wants to overwrite an existing key.
	if [[ -f "${config_file}" ]]; then
		local yes_no
		read -p "SimpleBackup configuration for key \"${key}\" already exists. Overwrite [Y/N]? " -n 1 -r yes_no
		echo
		case "${yes_no}" in
			y|Y)
				rm -rf "${config_file}"
				if [[ ${?} -ne 0 ]]; then
					echo "Unable to remove existing configuration. Aborting."
					return 1;
				fi
				;;
			n|N)
				echo "Adding key \"${key}\" cancelled by user. Aborting."
				return 1
				;;
			*)
				echo "Invalid option \"${yes_no}\". Please explicitly use [Y/N]. Aborting."
				return 1
				;;
		esac
	fi

	# Set up env var context so write-config can print it out.
	unset SIMPLEBACKUP_SOURCE
	unset SIMPLEBACKUP_DESTINATION
	unset SIMPLEBACKUP_FILTERS
	declare -g SIMPLEBACKUP_SOURCE="${source}"
	declare -g SIMPLEBACKUP_DESTINATION="${destination}"
	declare -gA SIMPLEBACKUP_FILTERS=()

	sbup-writeconfig "${key}"
	if [[ ${?} -ne 0 ]]; then
		return 1;
	fi
	
	echo "Key \"${key}\" added to SimpleBackup configuration."
}


# Remove a key from the SimpleBackup configuration.
# Arguments:
#   $1 - The name of the key to remove from the configuration.
sbup-remove() {
	# Get the key, abort if not provided.
	local key="${1}"
	if [[ -z "${key// }" ]]; then
		echo "Key not provided. Aborting."
		return 1
	fi
	
	local config_file="${SIMPLEBACKUP_CONFIG_DIR}/${key}"

	if [[ ! -d "${SIMPLEBACKUP_CONFIG_DIR}" ]]; then
		echo "SimpleBackup configuration directory \"${SIMPLEBACKUP_CONFIG_DIR}\" not found. Please run sbup-config. Aborting."
		return 1;
	fi
	
	# If the provided key exists, remove it. Otherwise terminate.
	if [[ ! -f "${config_file}" ]]; then
		echo "Key \"${key}\" not found in SimpleBackup configuration. Aborting."
		return 1
	fi

	rm -rf "${config_file}"
	if [[ ${?} -ne 0 ]]; then
		echo "Unable to remove existing configuration. Aborting."
		return 1;
	fi
	echo "Key \"${key}\" removed from SimpleBackup configuration."
}


# Add one or more filters to a key's configuration. Filters use the same syntax
# as rsync's --exclude (because that's what we're passing it to under the hood,
# duh). Duplicate entries are ignored.
# Arguments:
#   $1 - The name of the key to add filters for.
#   $2 .. $n - The filter expressions to add.
sbup-addfilters() {
	# Get the key, abort if not provided.
	local key="${1}"
	if [[ -z "${key// }" ]]; then
		echo "Key not provided. Aborting."
		return 1
	fi
	
	sbup-loadconfig "${key}"
	if [[ ${?} -ne 0 ]]; then
		return 1;
	fi

	# Bump out the key and then process all the remaining arguments as filter expressions.
	shift
	while (($#)) ; do
		local filter="${1}"
		shift
		if [[ -v SIMPLEBACKUP_FILTERS["${filter}"] ]]; then
			echo "Skipping duplicate filter \"${filter}\"."
			continue
		fi
		SIMPLEBACKUP_FILTERS["${filter}"]=""
	done

	sbup-writeconfig "${key}"
}


# Remove one or more filters from a key's configuration. Non-present filter
# expressions are ignored.
# Arguments:
#   $1 - The name of the key to remove from the configuration.
#   $2 .. $n - The filter expressions to remove.
sbup-removefilters() {
	# Get the key, abort if not provided.
	local key="${1}"
	if [[ -z "${key// }" ]]; then
		echo "Key not provided. Aborting."
		return 1
	fi
	
	sbup-loadconfig "${key}"
	if [[ ${?} -ne 0 ]]; then
		return 1;
	fi

	# Bump out the key and then process all the remaining arguments as filter expressions.
	shift
	while (($#)) ; do
		local filter="${1}"
		shift
		if [[ ! -v SIMPLEBACKUP_FILTERS["${filter}"] ]]; then
			echo "Skipping non-present filter \"${filter}\"."
			continue
		fi
		unset SIMPLEBACKUP_FILTERS["${filter}"]
	done

	sbup-writeconfig "${key}"
}


# Move files from the configured source to the configured destination.
# Arguments:
#   $1 - The key whose configuration will be used to save.
sbup-save() {
	# Get the key, abort if not provided.
	local key="${1}"
	if [[ -z "${key// }" ]]; then
		echo "Key not provided. Aborting."
		return 1
	fi

	sbup-loadconfig "${key}"
	if [[ ${?} -ne 0 ]]; then
		return 1;
	fi

	# If either the source or destination does not exist at this point in time, abort.
	if [[ ! -d "${SIMPLEBACKUP_SOURCE}" ]]; then
		echo "Save source \"${SIMPLEBACKUP_SOURCE}\" is not a directory. Aborting."
		return 1
	fi
	if [[ ! -d "${SIMPLEBACKUP_DESTINATION}" ]]; then
		echo "Save destination \"${SIMPLEBACKUP_DESTINATION}\" is not a directory. Aborting."
		return 1
	fi

    # Abort if the source and destination point to the same place.
	if [[ "${SIMPLEBACKUP_SOURCE}" -ef "${SIMPLEBACKUP_DESTINATION}" ]]; then
		echo "Source \"${SIMPLEBACKUP_SOURCE}\" and destination are identical. Aborting."
		return 1
	fi

	echo "Saving files for configuration \"${key}\"."

	# Turn the list of filters (i.e. each key in the associative array) into an
	# array of exlucde arguments.
	local filters=("${!SIMPLEBACKUP_FILTERS[@]}")
	filters=("${filters[@]/#/--exclude=}")

	rsync -a --delete "${filters[@]}" "${SIMPLEBACKUP_SOURCE}/" "${SIMPLEBACKUP_DESTINATION}/"
	if [[ ${?} -ne 0 ]]; then
		echo "Saving files failed. Aborting."
		return 1
	fi
}


# Move files from the configured destination to the configured source.
# Arguments:
#   $1 - The key whose configuration will be used to load.
sbup-load() {
	# Get the key, abort if not provided.
	local key="${1}"
	if [[ -z "${key// }" ]]; then
		echo "Key not provided. Aborting."
		return 1
	fi

	sbup-loadconfig "${key}"
	if [[ ${?} -ne 0 ]]; then
		return 1;
	fi

	# If either the source or destination does not exist at this point in time, abort.
	if [[ ! -d "${SIMPLEBACKUP_SOURCE}" ]]; then
		echo "Save source \"${SIMPLEBACKUP_SOURCE}\" is not a directory. Aborting."
		return 1
	fi
	if [[ ! -d "${SIMPLEBACKUP_DESTINATION}" ]]; then
		echo "Save destination \"${SIMPLEBACKUP_DESTINATION}\" is not a directory. Aborting."
		return 1
	fi

    # Abort if the source and destination point to the same place.
	if [[ "${SIMPLEBACKUP_SOURCE}" -ef "${SIMPLEBACKUP_DESTINATION}" ]]; then
		echo "Source \"${SIMPLEBACKUP_SOURCE}\" and destination are identical. Aborting."
		return 1
	fi

	echo "Loading files for configuration \"${key}\"."
	
	# Turn the list of filters (i.e. each key in the associative array) into an
	# array of exlucde arguments.
	local filters=("${!SIMPLEBACKUP_FILTERS[@]}")
	filters=("${filters[@]/#/--exclude=}")
	
	rsync -a --delete "${filters[@]}" "${SIMPLEBACKUP_DESTINATION}/" "${SIMPLEBACKUP_SOURCE}/"
	if [[ ${?} -ne 0 ]]; then
		echo "Loading files failed. Aborting."
		return 1
	fi
}

