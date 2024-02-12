#!/bin/bash
# This script performs a backup of the specified directories from the source drive to the backup drives.
# By Sébastien ETCHETO

default_config_file="$HOME/.backup/backup-hdd.config"

usage() {
    cat <<EOF
    Usage: $0 [-c <config_file>]
    Options:
      -c, --config <config_file>   Specify the configuration file to use (default: $default_config_file)
EOF

    exit 1
}

# Configuration file
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
    -c | --config)
        config_file="$2"
        shift
        shift
        ;;
    *)
        echo "Unknown option: $key"
        usage
        exit 1
        ;;
    esac
done

config_file="${config_file:-$default_config_file}"

if [ ! -f "$config_file" ]; then
    echo "The configuration file '$config_file' doesn't exist."
    exit 1
fi

# Load and check the configuration file
source "$config_file" || {
    echo "Failed to load configuration file '$config_file'."
    exit 1
}

if [ -z "$source_dir" ] || [ -z "$backup_dir1" ] || [ -z "$backup_dir2" ]; then
    echo "The paths of the hard drives are not defined in the configuration file."
    exit 1
fi

if [ ! -d "$source_dir" ]; then
    echo "The source directory '$source_dir' doesn't exist. Please verify the specified path."
    exit 1
fi

if [ ! -d "$backup_dir1" ]; then
    echo "Backup directory 1 '$backup_dir1' does not exist. Please verify the specified path."
    exit 1
fi

if [ ! -d "$backup_dir2" ]; then
    echo "Backup directory 2 '$backup_dir2' does not exist. Please verify the specified path."
    exit 1
fi

if [ "$source_dir" = "$backup_dir1" ] || [ "$source_dir" = "$backup_dir2" ]; then
    echo "Backup directories cannot be the same as the source directory."
    exit 1
fi

# Paths confirmation
cat <<EOF
The following paths will be used for the backup:

Source drive: $source_dir

Backup drive 1: $backup_dir1
Directories to backup on backup drive 1: $folders_to_backup1

Backup drive 2: $backup_dir2
Directories to backup on backup drive 2: $folders_to_backup2

EOF

read -p "Do you confirm that the above paths are correct? (Y/N) " confirm_paths

if [[ "$confirm_paths" != [yY] ]]; then
    echo "Backup canceled"
    exit 0
fi

# Function to perform backup for a directory
perform_backup() {
    local source_dir="$1"
    local backup_dir="$2"
    local folders_to_backup="$3"

    if [ ! -d "$source_dir" ]; then
        echo "The source directory '$source_dir' doesn't exist. Please verify the specified path."
        exit 1
    fi

    if [ ! -d "$backup_dir" ]; then
        echo "The backup directory '$backup_dir' doesn't exist. Please verify the specified path."
        exit 1
    fi

    for folder in $folders_to_backup; do
        if [ ! -d "$source_dir/$folder" ]; then
            echo "The directory '$source_dir/$folder' doesn't exist. Please verify the specified path."
            continue
        fi

        echo "Synchronizing files from '$source_dir/$folder' to '$backup_dir/$folder'"
        rsync -avz --delete "$source_dir/$folder" "$backup_dir/"
    done
}

# Perform backup for each specified directory
perform_backup "$source_dir" "$backup_dir1" "$folders_to_backup1"
perform_backup "$source_dir" "$backup_dir2" "$folders_to_backup2"

echo "Backup completed on the secondary drives."
exit 0