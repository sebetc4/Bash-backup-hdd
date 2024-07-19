#!/bin/bash

default_config_file="$HOME/.backup/backup-hdd.yml"

usage() {
    cat <<EOF
This script performs a backup of the specified directories from the source drive to the backup drives.
Usage: $0 [-c <config_file>] [-d <drive>] [--no-delete] [--no-progress]
Options:
    -c, --config <config_file>   Specify the configuration file to use (default: $default_config_file)
    -d, --drive <drive>          Specify the drive to backup: 1 (Backup drive 1), 2 (Backup drive 2), both (Backup drive 1 and 2) (default: both)
    --no-delete                  Do not delete files in the destination that are not in the source
    --no-progress                Do not show progress during file transfer
    -h, --help                   Display help message
EOF
    exit 1
}

# Parse command line options
no_delete=false
no_progress=false
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
    -c | --config)
        config_file="$2"
        shift
        shift
        ;;
    -d | --drive)
        drive="$2"
        shift
        shift
        ;;
    --no-delete)
        no_delete=true
        shift
        ;;
    --no-progress)
        no_progress=true
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

if ! command -v yq &> /dev/null; then
    echo "yq could not be found. Please install yq to use this script."
    exit 1
fi

# Validate drive option
if [ -z "$drive" ]; then
    drive="both"
fi

if [ "$drive" != "1" ] && [ "$drive" != "2" ] && [ "$drive" != "both" ]; then
    echo "Invalid drive option. Please specify '1', '2' or 'both'."
    exit 1
fi

# Load configuration file
config_file="${config_file:-$default_config_file}"

if [ ! -f "$config_file" ]; then
    echo "The configuration file '$config_file' doesn't exist."
    exit 1
fi

source_dir=$(yq e '.source.dir' "$config_file")
backup_dir1=$(yq e '.backup_drive_1.dir' "$config_file")
backup_dir2=$(yq e '.backup_drive_2.dir' "$config_file")
folders_to_backup1=$(yq e '.backup_drive_1.folders[]' "$config_file" | tr '\n' ' ')
folders_to_backup2=$(yq e '.backup_drive_2.folders[]' "$config_file" | tr '\n' ' ')

validate_paths() {
    local path=$1
    local name=$2

    if [ -z "$path" ]; then
        echo "$name directory is not defined in the configuration file."
        exit 1
    fi
    if [ ! -d "$path" ]; then
        echo "$name directory '$path' doesn't exist. Please verify the specified path."
        exit 1
    fi
}

validate_paths "$source_dir" "Source drive"
if [ "$drive" = "1" ] || [ "$drive" = "both" ]; then
    validate_paths "$backup_dir1" "Backup drive 1"
fi
if [ "$drive" = "2" ] || [ "$drive" = "both" ]; then
    validate_paths "$backup_dir2" "Backup drive 2"
fi

if [ "$source_dir" = "$backup_dir1" ] || [ "$source_dir" = "$backup_dir2" ]; then
    echo "Backup directories cannot be the same as the source directory."
    exit 1
fi

cleanup() {
    pkill -TERM rsync
    echo "Backup process interrupted"
    exit 1
}

trap cleanup SIGINT SIGTERM

print_paths_confirmation() {
    cat <<EOF
The following paths will be used for the backup:

Source drive: 
    path: $source_dir

EOF

    if [ "$drive" = "1" ] || [ "$drive" = "both" ]; then
        cat <<EOF
Backup drive 1: 
    path: $backup_dir1
    directories to backup: $folders_to_backup1

EOF
    fi

    if [ "$drive" = "2" ] || [ "$drive" = "both" ]; then
        cat <<EOF
Backup drive 2: 
    path: $backup_dir2
    directories to backup: $folders_to_backup2

EOF
    fi

    if [ "$no_delete" = false ];then
        cat <<EOF
Warning: Files in the destination directories that are not present in the source will be deleted.

EOF
    fi
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

    rsync_options="-avz"
    if [ "$no_delete" = false ]; then
        rsync_options="$rsync_options --delete"
    fi
    if [ "$no_progress" = false ]; then
        rsync_options="$rsync_options --progress"
    fi

    for folder in $folders_to_backup; do
        if [ ! -d "$source_dir/$folder" ]; then
            echo "The directory '$source_dir/$folder' doesn't exist. Please verify the specified path."
            continue
        fi

        echo "Synchronizing files from '$source_dir/$folder' to '$backup_dir/$folder'"
        rsync $rsync_options "$source_dir/$folder" "$backup_dir/"
    done
}

if [ "$drive" = "1" ] || [ "$drive" = "both" ]; then
    perform_backup "$source_dir" "$backup_dir1" "$folders_to_backup1"
fi
if [ "$drive" = "2" ] || [ "$drive" = "both" ]; then
    perform_backup "$source_dir" "$backup_dir2" "$folders_to_backup2"
fi

echo "Backup completed on the secondary drives."
exit 0
