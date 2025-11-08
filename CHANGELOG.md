# Changelog

All notable changes to this project will be documented in this file.

## [2.2.0] - 2025-11-07

### Added
- **Parallel upload control**: New `MAX_PARALLEL` environment variable (default: 5)
- **Graceful shutdown**: Signal handlers for SIGTERM and SIGINT with proper cleanup
- **Thread-safe queue operations**: Using `flock` for atomic file operations
- **Simplified path building**: New `build_remote_path()` function
- Function `wait_for_job_slot()` for controlling concurrent uploads
- Function `cleanup()` for handling graceful shutdown

### Changed
- **Removed `set -e`**: Explicit error handling instead of automatic exit
- **Function renaming**: 
  - `upload_to_s3` → `upload_with_queue`
  - `upload_to_s3_internal` → `upload_file`
- **Refactored queue operations**: Now thread-safe with flock
- **Improved code structure**: Reduced complexity while adding functionality
- **Error logging**: `log_error()` now writes to stderr
- **DRY-RUN improvement**: No longer requires RCLONE_REMOTE configuration for testing

### Fixed
- Race conditions in queue file operations during parallel uploads
- System overload when multiple files appear simultaneously
- Potential data loss during container shutdown
- DRY-RUN mode now works without cloud configuration

### Performance
- Protected against resource exhaustion with configurable parallelism
- More efficient path construction (reduced from 16 to 8 lines)
- Better resource management with controlled concurrent uploads

## [2.1.0] - 2025-11-06

### Changed
- Minimal logging: only success and error events
- All logs and code comments translated to English
- Removed color codes from logs for better compatibility
- Removed emojis from logs
- Silent operation mode - only important events logged

### Removed
- Log file storage - logs only to stdout/stderr
- Log directory mounting in docker-compose
- Startup logs and intermediate action logs

## [2.0.0] - 2025-11-05

### Added
- Migration from AWS CLI to rclone
- Universal cloud provider support (40+ services)
- Queue system for failed uploads
- Automatic retry on connection restore
- Configuration via environment variables only

### Changed
- All files are now uploaded (no extension filtering)
- Files are copied, not moved (local files remain)

### Removed
- AWS CLI dependency
- Existing file upload on startup
- Local file deletion after upload
- .env file requirement

## [1.2.0] - 2025-11-04

### Added
- Comprehensive documentation for ENV variable passing
- CHEATSHEET.md with command examples
- Extended troubleshooting section

## [1.1.0] - 2025-11-03

### Added
- DRY-RUN mode for testing without actual uploads
- Upload simulation with logging
- File size display in dry-run mode

## [1.0.0] - 2025-11-02

### Added
- Initial release
- File system monitoring via inotifywait
- Upload to S3-compatible storage via AWS CLI
- Docker containerization
- Docker Compose orchestration
- Flexible configuration via ENV variables


