#!/bin/bash

#How to Use the Script
#Save the Script:
#Save the code above into a file, for example, backup_script.sh.

#Make it Executable:
#Open your terminal and navigate to the directory where you saved the file. Then, run:

#chmod +x backup_script.sh
#User backup (e.g., /home/your_user): Can be run as your regular user.
#Full system backup (e.g., /): Requires root privileges to read all files and directories. You would typically add the cron job to root's crontab (sudo crontab -e).

# --- Configuration ---
# For full system backup, consider using '/' but be aware of exclusions.
SOURCE_DIR="/home/lastpatriot" # Example: Change to / for full system backup

# Destination directory for backups
# Ensure this directory exists and has enough space.
BACKUP_BASE_DIR="/mnt/backups/system_backup" # Example: Change to your backup drive/location

# Number of days to retain old backups
RETENTION_DAYS=7

# --- Logging ---
LOG_DIR="${BACKUP_BASE_DIR}/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${LOG_DIR}/backup_${TIMESTAMP}.log"

# --- Exclusions (for rsync) ---
# These are common exclusions for a full system backup to avoid
# transient data, virtual filesystems, and large unnecessary directories.
# Adjust as needed based on your SOURCE_DIR.
EXCLUDE_LIST=(
    "/dev/*"
    "/proc/*"
    "/sys/*"
    "/tmp/*"
    "/run/*"
    "/mnt/*"
    "/media/*"
    "/lost+found/*"
    "/var/cache/apt/archives/*" # Exclude downloaded package archives
    "/var/tmp/*"
    "/var/log/*" # Exclude logs (optional, depends on if you need them in backup)
    "/home/*/.cache/*" # Common user cache directories
    "/home/*/.mozilla/*/Cache/*"
    "/home/*/.thunderbird/*/Cache/*"
    "/home/*/.config/Code/User/globalStorage/*" # VS Code large storage
    "/home/*/.local/share/Trash/*" # Trash directory
    "/swapfile" # If you have a swapfile at root
    # Add any other directories you want to exclude, e.g., cloud sync folders:
    # "/home/your_user/Google Drive/*"
    # "/home/your_user/Dropbox/*"
)

# Convert array to rsync --exclude format
RSYNC_EXCLUDES=""
for item in "${EXCLUDE_LIST[@]}"; do
    RSYNC_EXCLUDES+="--exclude=${item} "
done

# --- Script Logic ---

echo "Starting system backup at ${TIMESTAMP}..." | tee -a "${LOG_FILE}"

# Create base backup directory if it doesn't exist
mkdir -p "${BACKUP_BASE_DIR}/current"
mkdir -p "${LOG_DIR}"

# Determine the previous successful backup for incremental linking
# This assumes 'current' always points to the last successful full backup.
LAST_SUCCESSFUL_BACKUP=$(find "${BACKUP_BASE_DIR}" -maxdepth 1 -name "backup_*-complete" -type d | sort -r | head -n 1)

# Set --link-dest option for rsync for incremental backups
LINK_DEST_OPTION=""
if [ -n "${LAST_SUCCESSFUL_BACKUP}" ]; then
    LINK_DEST_OPTION="--link-dest=${LAST_SUCCESSFUL_BACKUP}"
    echo "Using incremental backup based on: ${LAST_SUCCESSFUL_BACKUP}" | tee -a "${LOG_FILE}"
else
    echo "No previous full backup found for incremental linking. Performing full copy." | tee -a "${LOG_FILE}"
fi

# Run rsync
# -a: archive mode (recursively, preserve symlinks, permissions, times, group, owner)
# -v: verbose output
# -z: compress file data during transfer
# --info=progress2: show overall progress (for interactive run, less useful for cron)
# --delete: (OPTIONAL) If you want to delete files in destination that no longer exist in source.
#           Use with caution, especially for full system backups, as it can remove files
#           from previous snapshots if SOURCE_DIR is not comprehensive.
#           For this script, we are creating new dated snapshots, so --delete on 'current'
#           then renaming 'current' is safer.
rsync -avz \
      ${LINK_DEST_OPTION} \
      ${RSYNC_EXCLUDES} \
      "${SOURCE_DIR}" \
      "${BACKUP_BASE_DIR}/current" 2>&1 | tee -a "${LOG_FILE}"

RSYNC_EXIT_STATUS=${PIPESTATUS[0]} # Get exit status of rsync

if [ ${RSYNC_EXIT_STATUS} -eq 0 ]; then
    echo "Rsync completed successfully." | tee -a "${LOG_FILE}"

    # Rename the 'current' backup to a timestamped directory
    mv "${BACKUP_BASE_DIR}/current" "${BACKUP_BASE_DIR}/backup_${TIMESTAMP}-complete"
    if [ $? -eq 0 ]; then
        echo "Backup snapshot created: ${BACKUP_BASE_DIR}/backup_${TIMESTAMP}-complete" | tee -a "${LOG_FILE}"
    else
        echo "ERROR: Failed to rename 'current' backup to timestamped directory." | tee -a "${LOG_FILE}"
        # Attempt to clean up 'current' if rename failed (optional, depends on desired behavior)
        # rm -rf "${BACKUP_BASE_DIR}/current"
    fi

    # Clean up old backups
    echo "Cleaning up old backups (retaining for ${RETENTION_DAYS} days)..." | tee -a "${LOG_FILE}"
    find "${BACKUP_BASE_DIR}" -maxdepth 1 -type d -name "backup_*-complete" -mtime +"${RETENTION_DAYS}" -exec rm -rf {} \; 2>&1 | tee -a "${LOG_FILE}"
    echo "Old backup cleanup complete." | tee -a "${LOG_FILE}"

else
    echo "ERROR: Rsync failed with exit status ${RSYNC_EXIT_STATUS}. See log for details." | tee -a "${LOG_FILE}"
    # Optionally, rename 'current' to indicate a failed backup if needed
    # mv "${BACKUP_BASE_DIR}/current" "${BACKUP_BASE_DIR}/backup_${TIMESTAMP}-failed"
fi

echo "Backup script finished at $(date +%Y%m%d-%H%M%S)." | tee -a "${LOG_FILE}"
