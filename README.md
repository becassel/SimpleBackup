<!---
README.md. The README for SimpleBackup.
Copyright (C) 2025 Benjamin Cassell

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see <http://www.gnu.org/licenses/>.
-->

# SimpleBackup

A simple script for backing up and restoring data from named directories.

## Setup and Configuration

The features provided in this script are all plain-old Bash. Several features
use newer Bash functionalities (e.g. associative arrays and quoted variable
expansion), so Bash 4.4 or newer is recommended. The script itself was created
on the Windows Subsystem for Linux (WSL), although it is intended to be used in
other environments as well (e.g. your favourite Linux distribution, your
SteamDeck, Cygwin, your Macbook). I actually wrote this script in the first
place so I could easily sync offline Diablo 2: Resurrected characters to and
from my Git repository on my PC and my SteamDeck. I hope you find some cool
other uses.

Start by adding simplebackup.sh to at least one of the scripts that runs during
your shell startup (e.g. .profile, .bashrc, etc.):

```
source somepath/simplebackup.sh
```

Where `somepath` is the directory in which you have saved the script. You may
need to restart your session after making this change:

```
exec bash
```

Next, run the config command to generate a configuration directory for the
script. SimpleBackup will look for its configuration files in this directory
(`${HOME}/.simplebackup`):

```
sbup-config
```

## Adding and Removing Keys

SimpleBackup adds configuration files using keys. To create a new configuration
file with a given key, source path, and destination path, use the add command:

```
sbup-add mykey source destination
```

Further interactions with the script will use this key to adjust the
configuration, move files, etc. If the key already exists at creation time, you
will be asked to either overwrite it (deleting all previous contents) or abort.

You can remove an existing key and all of its associated configurations with
the following command:

```
sbup-remove mykey
```

You can see the contents of a particular key's configuration using the
showconfig command:

```
sbup-showconfig mykey
```

## Saving Files

To create a backup of files for a configured key, run:

```
sbup-save mykey
```

Saving is a destructive operation. Files that are not present in the source directory
will be removed from the destination directory, unless they match a filter pattern.

## Restoring Files

To restore a backup of files for a configured key, run:

```
sbup-load mykey
```

Loading is a destructive operation. Files that are not present in the
destination directory will be removed from the source directory, unless they
match a filter pattern.

## Adding and Removing Filters

When saving and restoring files, SimpleBackup ignores files present in the
filters list (i.e. it will not copy files from the source, nor delete files
from the destination, if they match a pattern on the filter list). To add
filters, run:

```
sbup-addfilters mykey filter1 filter2 ...
```

To remove filters, run:

```
sbup-removefilters mykey filter1 filter2 ...
```

Filters use the same syntax pattern as exclude patterns for rsync.

