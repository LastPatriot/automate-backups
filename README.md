# Automated System Backup Script

This Bash script provides a simple yet powerful solution for creating incremental, timestamped backups using `rsync`. It's designed to be easily scheduled with `cron` for regular, hands-off backups.

## Features

- **Incremental Backups**: Uses `rsync`'s `--link-dest` to create space-efficient backups by hard-linking unchanged files from the previous snapshot. This means only new and modified files take up additional space.
- **Timestamped Snapshots**: Each successful backup creates a new directory with a timestamp (`backup_YYYYMMDD-HHMMSS-complete`), making it easy to browse and restore from specific points in time.
- **Automated Cleanup**: Automatically deletes old backup snapshots based on a configurable retention period (`RETENTION_DAYS`).
- **Configurable**: Easily change the source and destination directories, as well as the retention period.
- **Comprehensive Exclusions**: Includes a list of common directories and files to exclude from a system backup (e.g., virtual filesystems, cache directories, logs) to save space and avoid backing up unnecessary, transient data.
- **Robust Logging**: All script output is logged to a timestamped file in a dedicated `logs` directory, making it easy to diagnose any issues.

## Getting Started

### 1. Save the Script

Save the script to a file, for example, `backup_script.sh`.

### 2. Configure Your Backup

Open the script in a text editor and modify the following variables in the "Configuration" section:

- `SOURCE_DIR`: The directory you want to back up. For a full system backup, set this to `/`. For a user's home directory backup, set it to `/home/your_user`.
- `BACKUP_BASE_DIR`: The destination for your backups. Ensure this directory exists and has enough free space. For example, `/mnt/backups/system_backup`.
- `RETENTION_DAYS`: The number of days to keep old backup snapshots.

> ⚠️ **Warning**: For a full system backup (`SOURCE_DIR="/" `), the script requires root privileges. You'll need to run it as the root user or with `sudo`.

### 3. Make it Executable

Open your terminal, navigate to where you saved the script, and run the following command to make it executable:

```bash
chmod +x backup_script.sh
