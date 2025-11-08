<div align="center">

# 📦 rclone-watch

**Event-driven real-time file uploader to cloud storage via rclone**

[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Alpine Linux](https://img.shields.io/badge/Alpine-3.19-0D597F?logo=alpinelinux&logoColor=white)](https://alpinelinux.org/)
[![rclone](https://img.shields.io/badge/rclone-Powered-0078D7?logo=rclone&logoColor=white)](https://rclone.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)

[![Cloud Providers](https://img.shields.io/badge/Cloud_Providers-40+-blue)](#-examples)
[![Version](https://img.shields.io/badge/Version-2.2.0-orange)](CHANGELOG.md)
[![Maintenance](https://img.shields.io/badge/Maintained-Yes-success)](https://github.com/dx8ug/rclone-watch)
[![Topics](https://img.shields.io/badge/Topics-docker%20%7C%20rclone%20%7C%20backup-informational)](https://github.com/topics/rclone)

[Quick Start](#-quick-start) • [Configuration](#️-configuration) • [Examples](#-examples) • [FAQ](#-faq)

</div>

---

## 📖 About

Monitor any directory and automatically upload new files to cloud storage in real-time using rclone. Perfect for NAS, surveillance cameras, or any automated backup needs.

- 🎯 **Event-driven** — instant upload on file detection via inotify
- 🔄 **Fault-tolerant** — automatic retry queue for failed uploads
- ☁️ **Universal** — 40+ cloud providers (S3, Google Drive, Dropbox, Backblaze, etc.)
- 🐳 **Simple** — configuration via environment variables only
- 📦 **Lightweight** — Alpine Linux based (~50MB)

---

## 🚀 Quick Start

```bash
git clone https://github.com/dx8ug/rclone-watch.git
cd rclone-watch

# Configure
export WATCH_PATH=/mnt/nas/surveillance  # Any directory you want to watch
export RCLONE_REMOTE=myremote:my-bucket
export RCLONE_CONFIG_MYREMOTE_TYPE=s3
export RCLONE_CONFIG_MYREMOTE_PROVIDER=AWS
export RCLONE_CONFIG_MYREMOTE_ACCESS_KEY_ID=your-key
export RCLONE_CONFIG_MYREMOTE_SECRET_ACCESS_KEY=your-secret
export RCLONE_CONFIG_MYREMOTE_REGION=us-east-1

# Start
docker-compose up -d
docker-compose logs -f
```

---

## ⚙️ Configuration

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `WATCH_PATH` | Directory to watch | `/mnt/nas/surveillance`, `/data/backup`, `/home/user/uploads` |
| `RCLONE_REMOTE` | Remote:bucket | `s3:my-bucket` |
| `RCLONE_CONFIG_{NAME}_TYPE` | Storage type | `s3`, `drive`, `b2` |
| `RCLONE_CONFIG_{NAME}_ACCESS_KEY_ID` | Access key | Your key |
| `RCLONE_CONFIG_{NAME}_SECRET_ACCESS_KEY` | Secret key | Your secret |

> 💡 Format: `RCLONE_CONFIG_{REMOTE_NAME}_{PARAMETER}`

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `RCLONE_CONFIG_{NAME}_ENDPOINT` | — | S3 endpoint |
| `RCLONE_CONFIG_{NAME}_REGION` | — | Region |
| `S3_PREFIX` | — | Subfolder prefix |
| `UPLOAD_DELAY` | `5` | Delay (seconds) |
| `MAX_PARALLEL` | `5` | Concurrent uploads |
| `DRY_RUN` | `false` | Test mode |

---

## 💡 Examples

### Amazon S3
```bash
export RCLONE_REMOTE=s3:my-bucket
export RCLONE_CONFIG_S3_TYPE=s3
export RCLONE_CONFIG_S3_PROVIDER=AWS
export RCLONE_CONFIG_S3_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export RCLONE_CONFIG_S3_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export RCLONE_CONFIG_S3_REGION=us-east-1
docker-compose up -d
```

### Backblaze B2
```bash
export RCLONE_REMOTE=b2:my-bucket
export RCLONE_CONFIG_B2_TYPE=b2
export RCLONE_CONFIG_B2_ACCOUNT=your-account-id
export RCLONE_CONFIG_B2_KEY=your-app-key
docker-compose up -d
```

### Google Drive
```bash
export RCLONE_REMOTE=gdrive:BackupFolder
export RCLONE_CONFIG_GDRIVE_TYPE=drive
export RCLONE_CONFIG_GDRIVE_CLIENT_ID=your-client-id
export RCLONE_CONFIG_GDRIVE_CLIENT_SECRET=your-secret
export RCLONE_CONFIG_GDRIVE_TOKEN=your-token
docker-compose up -d
```

### Dry-run Test
```bash
DRY_RUN=true WATCH_PATH=/mnt/nas/surveillance docker-compose up
```

---

## 🔧 How It Works

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   Watched   │      │   Docker     │      │    Cloud    │
│  Directory  │─────▶│  inotifywait │─────▶│   Storage   │
│  New File   │      │   + rclone   │      │ S3/B2/Drive │
└─────────────┘      └──────────────┘      └─────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │ Upload Queue │
                     │ (on failure) │
                     └──────────────┘
```

1. **Monitor** files with inotifywait
2. **Wait** UPLOAD_DELAY seconds  
3. **Upload** via rclone (preserves folder structure)
4. **On failure** → add to queue
5. **On success** → process queue

**Folder Structure:**
```
/path/to/watch/2024/01/file.dat → myremote:bucket/2024/01/file.dat
```

With `S3_PREFIX=backup`:
```
/path/to/watch/2024/01/file.dat → myremote:bucket/backup/2024/01/file.dat
```

---

## 📊 Management

```bash
# Basic
docker-compose up -d              # Start
docker-compose down               # Stop
docker-compose logs -f            # Logs
docker-compose restart            # Restart

# Monitoring
docker exec rclone-watch cat /tmp/upload_queue.txt  # Check queue
docker exec rclone-watch rclone lsd $RCLONE_REMOTE  # Test connection
docker stats rclone-watch                           # Resources

# Update settings
S3_PREFIX=new-folder docker-compose up -d
```

---

## ❓ FAQ

**Q: Files not detected on macOS/Windows?**  
A: Docker Desktop has inotify limitations. Works on Linux. For testing: `docker exec rclone-watch touch /watch/test.txt`

**Q: Are local files deleted?**  
A: No, only copied.

**Q: What happens on connection loss?**  
A: Files queue automatically and retry on next upload.

**Q: How to filter file types?**  
A: Modify `rclone-watch.sh` script.

**Q: Need rclone.conf file?**  
A: No, auto-configured via `RCLONE_CONFIG_*` variables.

---

## 🐛 Troubleshooting

```bash
# Container won't start
docker-compose logs

# Files not uploading
docker exec rclone-watch rclone lsd $RCLONE_REMOTE
docker-compose logs | grep ERROR

# Check configuration
docker exec rclone-watch env | grep RCLONE
```

---

## 🔐 Security

- ✅ Use `:ro` (read-only) mount
- ✅ Environment variables only
- ✅ No credentials in files
- ✅ Limit cloud permissions

---

## 📚 Links

- [CHANGELOG.md](CHANGELOG.md)
- [rclone Documentation](https://rclone.org/docs/)
- [Docker Documentation](https://docs.docker.com/)

---

## 📄 License

MIT License. See [LICENSE](LICENSE).

---

<div align="center">

**Built with ❤️ for automated backup workflows**

⭐ Star on GitHub if this tool saves you time!

[⬆ Back to Top](#-rclone-watch)

</div>
