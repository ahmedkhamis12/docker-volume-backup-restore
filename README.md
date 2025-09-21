
# 🛡️ Docker Volume Backup & Restore System

This project provides an automated solution for backing up and restoring Docker volumes based on custom backup policies. It supports scheduling, retention, parallel execution, and remote offsite cleanup.

---

## 📦 Features

- 🔍 **Auto-detect Docker volumes** with a `backup-policy` label.
- 📅 **Flexible backup policies**:  
  - `daily-7` → backup every day, retain 7 days  
  - `weekly-30` → backup weekly, retain 30 days  
  - `every3days-10` → backup every 3 days, retain 10 days
- 🔁 **Retention enforcement** on remote backups.
- ⚡ **Parallel backups** with controlled concurrency.
- ☁️ **Remote offsite support** via SSH for backup cleanup.
- 🧪 **Restore script** with step-by-step recovery and validation.

---

## 📁 Repository Structure

```
.
├── backup_volume.sh          # Performs a single volume backup
├── auto_backup.sh                   # Main backup controller
├── restore.sh                # Restore script from remote zip
├── backups/                  # Local backups (generated)
├── logs/                     # Backup logs (generated)
├── .env                      # Configuration (SSH, remote paths)
└── README.md
```

---

## ⚙️ Setup

1. **Clone the repository**:

```bash
git clone https://github.com/ahmedkhamis12/docker-volume-backup-restore.git
cd docker-volume-backup-restore
```

2. **Configure `.env` file**:

Create a `.env` file with the following variables:

```ini
# .env
REMOTE_USER=your_ssh_username
REMOTE_HOST=your.remote.server
REMOTE_BACKUP_PATH=/home/your_user/backups
SSH_KEY_PATH=./path/to/your/private_key.pem
LOCAL_BACKUP_DIR=./restored_backups
```

3. **Add `backup-policy` labels to your Docker volumes**:

```bash
docker volume create --label backup-policy=daily-7 my_volume
```

4. **Run the main backup script**:

```bash
./auto_backup.sh
```

---

## 🔁 Restore a Volume

To restore a volume from a `.zip` backup:

```bash
 ./restore.sh <volume_name>
```

The script:
- Downloads the latest backup from the remote server
- Stops all containers using the volume
- Unzips data into the volume
- Restarts containers
- Verifies the restoration

---

## ⏱️ Automate with Cron

To schedule daily backups, add this to your crontab:

```bash
0 2 * * * /path/to/project/auto_backup.sh >> /path/to/project/logs/cron.log 2>&1
```

---

## 🔒 Security & Notes

- SSH key-based authentication is required for remote cleanup.
- Ensure the `REMOTE_BACKUP_PATH` exists and is writable on the remote host.
- This system assumes Docker volumes are accessible from the host running the script.

---

## ✅ Example Output

```
🔍 Scanning volumes with backup-policy...
📦 Volume: my_volume | Policy: daily-7
🔎 Checking my_volume: Last = 2025-07-13 02:00:00 | Diff = 3 days | Required = 1
▶️ Backing up my_volume...
🧹 Cleaning backups older than 7 days for my_volume on remote server...
✅ Done with my_volume.
🎉 All backups finished.
```

---

## 🧑‍💻 Author

**Ahmed Khamis**  
🔗 [GitHub](https://github.com/ahmedkhamis12)  
📧 Feel free to reach out for improvements, ideas, or questions!

---

## 📜 License

This project is open-source under the MIT License.

