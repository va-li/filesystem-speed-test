#!/bin/bash

# Script to measure the speed of writing a big file to a filesystem
# Author: Valentin Bauer

# Supposedly saner bash script behaviour
set -o errexit -o pipefail -o noclobber -o nounset

# --- Constants
# The name of the file where data is going to be written
readonly DATA_FILE="speed-dump.bin"
# At max, copy this number of bytes in one go (see 'man dd' > 'bs' parameter)
readonly DATA_BLOCK_SIZE=4096
# How many data blocks with size DATA_BLOCK_SIZE to copy 
readonly DATA_BLOCK_COUNT=1000000

print_usage() {
    echo "Usage: measure-write-speed [-h] [-n|--no-cache-clear] [-s|--samples] [-t|--target directory]"
}

# Some of the commands need root priviledges, can't go on without.
if [[ $(id -u) -ne 0 ]]; then
   echo "This script mus be run as root!"
   exit 1
fi

# --- Options
# Defining the available commandline options in short and long version for getopt
readonly OPTIONS=hnt:s:
readonly LONGOPTS=help,no-cache-clear,target:,samples:

# --- Arguments
# A file with arbitrary data is going to be written to this directory
TARGET_DIRECTORY="$(pwd)"
# How often to repeat the data write to the target directory
SAMPLE_RUNS=1
# To clear caches or not to clear
CLEAR_CACHES="0"

# Use return value from ${PIPESTATUS[0]}, because ! hosed $?
# Temporarily store output to be able to check for errors
# Activate quoting/enhanced mode (e.g. by writing out “--options”)
# Pass arguments only via   -- "$@"   to separate them correctly
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    exit 3
fi
# Read getopt’s output this way to handle the quoting right
eval set -- "$PARSED"

# Now work with the options in order and nicely split until we see --
while true; do
    case "$1" in
        -s|--samples)
            SAMPLE_RUNS="$2"
            shift 2
            ;;
        -t|--target)
            TARGET_DIRECTORY="$2"
            shift 2
            ;;
        -n|--no-cache-clear)
            CLEAR_CACHES="1"
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error!"
            exit 4
            ;;
    esac
done


for RUN in $(seq "${SAMPLE_RUNS}"); do
    echo "Starting run #${RUN}..."
    
    # Drop the system's page cache, dentries and inodes
    # see https://www.kernel.org/doc/html/latest/admin-guide/sysctl/vm.html#drop-caches
    if [[ ${CLEAR_CACHES} -eq 0 ]]; then
        sync
        sh -c "/usr/bin/echo 3 > /proc/sys/vm/drop_caches"
    fi

    # Copy data and show the progress and summary 'dd' gives
    dd \
        if=/dev/zero \
        of="${TARGET_DIRECTORY}/${DATA_FILE}" \
        bs="${DATA_BLOCK_SIZE}" \
        count="${DATA_BLOCK_COUNT}" \
        status=progress
done

rm "${TARGET_DIRECTORY}/${DATA_FILE}"
