#!/bin/bash

default_config_file="$HOME/.backup/backup-hdd.config"

usage() {
    cat <<EOF
This script performs a backup of the specified directories from the source drive to the backup drives.
Usage: $0 [-c <config_file>]
Options:
    -c, --config <config_file>   Specify the configuration file to use (default: $default_config_file)
EOF
    exit 1
}

# Parse command-line options
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
    -c | --config)
        config_file="$2"
        shift
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "Unknown option: $key"
        usage
        exit 1
        ;;
    esac
done

# Load configuration file
config_file="${config_file:-$default_config_file}"

if [ ! -f "$config_file" ]; then
    echo "The configuration file '$config_file' doesn't exist."
    exit 1
fi

source "$config_file" || {
    echo "Failed to load configuration file '$config_file'."
    exit 1
}

# Validate paths
validate_paths() {
    local path=$1
    local name=$2

    if [ -z "$path" ]; then
        echo "The $name directory is not defined in the configuration file."
        exit 1
    fi
    if [ ! -d "$path" ]; then
        echo "'$name' directory '$path' doesn't exist. Please verify the specified path."
        exit 1
    fi
}

validate_paths "$source_dir" "Source drive"
validate_paths "$backup_dir1" "Backup drive 1"
validate_paths "$backup_dir2" "Backup drive 2"

if [ "$source_dir" = "$backup_dir1" ] || [ "$source_dir" = "$backup_dir2" ]; then
    echo "Backup directories cannot be the same as the source directory."
    exit 1
fi

# Cleanup and exit on interrupt signal
cleanup() {
    pkill -TERM rsync
    echo "Backup process interrupted"
    exit 1
}

trap cleanup SIGINT SIGTERM

# Print and confirm paths
print_paths_confirmation() {
    cat <<EOF
The following paths will be used for the backup:

Source drive: 
    path: $source_dir

Backup drive 1: 
    path: $backup_dir1
    directories to backup: $folders_to_backup1

Backup drive 2: 
    path: $backup_dir2
    directories to backup: $folders_to_backup2

EOF
}

confirm_paths() {
    read -p "Do you confirm that the above paths are correct? (Y/N) " confirm
    if [[ "$confirm" != [yY] ]]; then
        echo "Backup canceled"
        exit 0
    fi
}

print_paths_confirmation
confirm_paths

# Perform backup for directories
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
        rsync -avz --delete --progress "$source_dir/$folder" "$backup_dir/"
    done
}

perform_backup "$source_dir" "$backup_dir1" "$folders_to_backup1"
perform_backup "$source_dir" "$backup_dir2" "$folders_to_backup2"

echo "Backup completed on the secondary drives."
exit 0
