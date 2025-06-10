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

# Setup
The features provided in this script are all plain-old Bash. Several features
use newer Bash functionalities (e.g. associative arrays and quoted variable
expansion), so you will need Bash 4.4 or newer. The script itself was created
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

Next, run the setup command to generate a config file for the script.
SimpleBackup will look for a configuration file in your home directory
(`${HOME}/.simplebackupconfig`). The setup command is:

```
sbup-config
```

# Use

SimpleBackup adds entries to your configuration file by providing it with a
key:

```
sbup-add mykey
```

Running this command will ask you to configure the key, e.g. by adding source
and destination directories. Further interactions with the script will use this
key to adjust the configuration, move files, etc.

You can remove an existing key and all of its associated configurations with
the following command:

```
sbup-remove mykey
```

## Backing up Files

To create a backup of files from a configured key, run:

```
sbup-save mykey
```

If the destination directory is not empty, a warning prompt will be issued
prior to continuing. Accepting the warning prompt will delete all files in the
destination directory before copying any new ones.

## Restore Files

To restore a backup of files from a configured key, run:

```
sbup-load mykey
```

If the source directory is not empty, a warning prompt will be issued
prior to continuing. Accepting the warning prompt will delete all files in the
source directory before copying the backed up.

