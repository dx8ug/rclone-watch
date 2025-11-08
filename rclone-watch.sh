#!/bin/bash

# Script for monitoring new files and uploading them to cloud via rclone

# Logging functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1"
}


# Default settings (set early to use in checks)
S3_PREFIX="${S3_PREFIX:-}"
UPLOAD_DELAY="${UPLOAD_DELAY:-5}"  # Delay before upload in seconds
DRY_RUN="${DRY_RUN:-false}"        # Test mode without real upload
MAX_PARALLEL="${MAX_PARALLEL:-5}"  # Maximum parallel uploads

# Check required environment variables
if [ -z "$WATCH_DIR" ]; then
    log_error "WATCH_DIR variable is not set"
    exit 1
fi

# In dry-run mode, remote configuration is not required
if [ "$DRY_RUN" != "true" ]; then
    if [ -z "$RCLONE_REMOTE" ]; then
        log_error "RCLONE_REMOTE variable is not set"
        exit 1
    fi
fi

# Check if watch directory exists
if [ ! -d "$WATCH_DIR" ]; then
    log_error "Watch directory does not exist: $WATCH_DIR"
    exit 1
fi

# rclone is configured via RCLONE_CONFIG_* environment variables
# No configuration files required!

# Queue file for failed uploads (stored in /tmp - no persistent logging)
QUEUE_FILE="/tmp/upload_queue.txt"
QUEUE_LOCK="${QUEUE_FILE}.lock"
touch "$QUEUE_FILE"

if [ "$DRY_RUN" = "true" ]; then
    log_warn "DRY-RUN MODE ENABLED - files will NOT be uploaded to cloud"
fi

# Graceful shutdown handler
cleanup() {
    log "Shutting down gracefully, waiting for background jobs..."
    wait
    log "Shutdown complete"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Parallel job control
wait_for_job_slot() {
    # Wait until number of background jobs is less than MAX_PARALLEL
    while [ "$(jobs -r | wc -l)" -ge "$MAX_PARALLEL" ]; do
        sleep 0.5
    done
}

# Function to build remote path with prefix support
build_remote_path() {
    local filepath="$1"
    local relative_path="${filepath#$WATCH_DIR/}"
    
    # Remove leading slash if exists
    relative_path="${relative_path#/}"
    
    # Build path: remote/[prefix/]relative_path
    if [ -n "$S3_PREFIX" ]; then
        echo "${RCLONE_REMOTE:-cloud}/${S3_PREFIX}/${relative_path}"
    else
        echo "${RCLONE_REMOTE:-cloud}/${relative_path}"
    fi
}

# Function to add file to queue (thread-safe with flock)
add_to_queue() {
    local filepath="$1"
    (
        flock -x 200
        if ! grep -qxF "$filepath" "$QUEUE_FILE" 2>/dev/null; then
            echo "$filepath" >> "$QUEUE_FILE"
            log "File added to queue: $(basename "$filepath")"
        fi
    ) 200>"$QUEUE_LOCK"
}

# Function to remove file from queue (thread-safe with flock)
remove_from_queue() {
    local filepath="$1"
    (
        flock -x 200
        local temp_file="${QUEUE_FILE}.tmp"
        grep -vxF "$filepath" "$QUEUE_FILE" > "$temp_file" 2>/dev/null || true
        mv "$temp_file" "$QUEUE_FILE"
    ) 200>"$QUEUE_LOCK"
}

# Function to process queue
process_queue() {
    [ -s "$QUEUE_FILE" ] || return 0
    
    (
        flock -x 200
        # Read queue line by line
        while IFS= read -r filepath; do
            # Check if file still exists
            if [ -f "$filepath" ]; then
                if upload_file "$filepath"; then
                    # Remove from queue only if upload succeeded
                    local temp_file="${QUEUE_FILE}.tmp"
                    grep -vxF "$filepath" "$QUEUE_FILE" > "$temp_file" 2>/dev/null || true
                    mv "$temp_file" "$QUEUE_FILE"
                    log "File from queue uploaded successfully: $(basename "$filepath")"
                else
                    # Stop processing queue if upload failed
                    break
                fi
            else
                # File does not exist, remove from queue silently
                local temp_file="${QUEUE_FILE}.tmp"
                grep -vxF "$filepath" "$QUEUE_FILE" > "$temp_file" 2>/dev/null || true
                mv "$temp_file" "$QUEUE_FILE"
            fi
        done < "$QUEUE_FILE"
    ) 200>"$QUEUE_LOCK"
}

# Core upload function (performs actual upload)
upload_file() {
    local filepath="$1"
    local filename=$(basename "$filepath")
    local remote_path=$(build_remote_path "$filepath")
    
    # DRY-RUN mode - only show what would happen
    if [ "$DRY_RUN" = "true" ]; then
        log_warn "[DRY-RUN] Will be uploaded: $filename -> $remote_path"
        local filesize=$(du -h "$filepath" | cut -f1)
        log_warn "[DRY-RUN] File size: $filesize"
        log_warn "[DRY-RUN] Simulation completed for: $filename"
        return 0
    fi
    
    # Upload file to cloud using rclone
    if rclone copyto "$filepath" "$remote_path" --progress 2>/dev/null; then
        log "Uploaded successfully: $filename"
        return 0
    else
        return 1
    fi
}

# Main upload handler with queue logic
upload_with_queue() {
    local filepath="$1"
    
    # Try to upload file
    if upload_file "$filepath"; then
        # If upload successful, try to process queue
        process_queue
    else
        # If upload failed, add to queue
        log_error "Upload failed: $(basename "$filepath")"
        add_to_queue "$filepath"
    fi
}

# Check rclone availability (skip in dry-run mode)
if [ "$DRY_RUN" = "true" ]; then
    log_warn "[DRY-RUN] Skipping cloud connection check"
fi

# Monitor directory with inotifywait
inotifywait -m -r -e close_write,moved_to "$WATCH_DIR" --format '%w%f' |
while read -r filepath; do
    # Check if it's a file (not directory)
    if [ -f "$filepath" ]; then
        # Wait a bit to make sure file is fully written
        if [ "$UPLOAD_DELAY" -gt 0 ]; then
            sleep "$UPLOAD_DELAY"
        fi
        
        # Wait for available job slot before starting upload
        wait_for_job_slot
        
        # Upload to cloud in background with parallel control
        upload_with_queue "$filepath" &
    fi
done
