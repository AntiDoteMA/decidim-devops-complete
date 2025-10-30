# Decidim Deployment (GitLab + Docker + Ubuntu)

This repository contains everything needed to deploy Decidim in a production environment using **Docker Compose** and **GitLab CI/CD**.

---

## 🧭 Prerequisites
- Ubuntu Server (20.04+)
- Docker & Docker Compose installed
- GitLab project created
- GitLab Runner registered on the server
- Domain name (e.g., decidim.badil2026.net)

---

## ⚙️ Setup Instructions

### 1. Clone Repo
```bash
git clone git@gitlab.com:badil2026-it-digital/decidim-badil2026.git
cd decidim-badil2026
```

### 2. Configure Environment
```bash
cp .env.example .env
# Edit .env with your values
```

### 3. Start Decidim Locally
```bash
docker-compose up -d
```
Access at: http://localhost:3000

---

## 🌐 Nginx & SSL
After confirming the app works, enable SSL:
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d decidim.badil2026.net
```

---

## 🚀 Deploy via GitLab
Push to the `main` branch to trigger CI/CD:
```bash
git add .
git commit -m "initial deploy"
git push origin main
```

Your GitLab Runner will automatically:
1. Build containers  
2. Pull latest Decidim  
3. Restart the stack

---

## 🧱 Structure

| File | Purpose |
|------|----------|
| `docker-compose.yml` | Container definitions |
| `.gitlab-ci.yml` | GitLab pipeline |
| `nginx.conf` | Proxy and SSL configuration |
| `.env` | Environment variables |
| `README.md` | Deployment guide |

---

## 🧰 Useful Commands

```bash
docker-compose logs -f decidim
docker-compose exec decidim rails console
docker-compose down && docker-compose up -d
```

---

## 📜 Notes
- For security, change default passwords.
- Use a dedicated GitLab Runner user (not root).
- Consider adding backups for `/pgdata` and `/uploads`.

---

Made with 💡 by the DevOps team.


---
## 💾 Backup & Restore

### Backup
Run daily or manually to backup DB and uploads:
```bash
./backup.sh
```

### Restore
To restore from a backup:
```bash
./restore.sh <backup_path>
```


### 📅 Automate Backups with Cron
To schedule daily backups at 2 AM, edit the crontab for your server user:
```bash
crontab -e
```
Add the following line:
```cron
0 2 * * * cd /path/to/decidim && ./backup.sh >> /path/to/decidim/backups/backup.log 2>&1
```
Replace `/path/to/decidim` with the path to your Decidim project. This will create daily backups automatically.
