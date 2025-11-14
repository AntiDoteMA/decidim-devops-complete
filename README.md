# Decidim Deployment (GitLab + Docker + Ubuntu)

This repository contains everything needed to deploy Decidim in a production environment using **Docker Compose** and **GitLab CI/CD**.

---

## 🧭 Prerequisites
- Ubuntu Server (20.04+)
- Docker & Docker Compose installed
- GitLab project created
- GitLab Runner registered on the server
- Domain name (e.g., decidim.DOMAIN_NAME.ext)

---

## 🚦 Getting Started

### First-Time Setup (Recommended)

1. **Follow the Deployment Checklist**
   ```bash
   # Read the complete checklist
   cat DEPLOYMENT_CHECKLIST.md
   ```

2. **Setup GitLab Runner**
   - See detailed instructions in `CICD_SETUP.md`

3. **Configure Environment**
   ```bash
   cp .env.example .env
   # Edit .env with your values
   ```

4. **Push and Deploy**
   ```bash
   git push origin main
   # Then manually trigger deploy_production in GitLab
   ```

5. **Setup SSL**
   ```bash
   sudo certbot --nginx -d your-domain.com
   ```

### Quick Links
- 📖 **New to CI/CD?** Start with [CICD_SETUP.md](CICD_SETUP.md)
- ⚡ **Need quick commands?** Check [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- ✅ **Ready to deploy?** Follow [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)
- 🎨 **Want to visualize?** See [WORKFLOW_DIAGRAMS.md](WORKFLOW_DIAGRAMS.md)

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
sudo certbot --nginx -d decidim.DOMAIN_NAME.ext
```

---

## 🚀 Deploy via GitLab CI/CD

### Quick Start
Push to the `main` branch and manually trigger deployment:
```bash
git add .
git commit -m "initial deploy"
git push origin main
```

Then go to **GitLab → CI/CD → Pipelines** and manually trigger the `deploy_production` job.

### Full CI/CD Pipeline Features:
- ✅ Configuration validation
- 🚀 Automated deployment with health checks
- 💾 Automatic backups after deployment
- ⏪ One-click rollback capability
- 🏥 Comprehensive health monitoring
- 📋 Log viewing and diagnostics
- 🕐 Scheduled daily backups

### Setup Guide
For complete CI/CD setup instructions, see **[CICD_SETUP.md](CICD_SETUP.md)**

---

## 🧱 Project Structure

### Core Files
| File | Purpose |
|------|----------|
| `docker-compose.yml` | Container definitions (Decidim, PostgreSQL, Redis, Nginx) |
| `.gitlab-ci.yml` | Complete CI/CD pipeline with 4 stages |
| `nginx.conf` | Reverse proxy and SSL configuration |
| `.env.example` | Environment variables template |
| `working_fresh_install_script.sh` | Manual installation script |
| `backup.sh` | Database and uploads backup script |
| `restore.sh` | Restore from backup script |

### Documentation
| File | Purpose |
|------|----------|
| `README.md` | This file - Quick start guide |
| `CICD_SETUP.md` | Complete CI/CD setup instructions |
| `QUICK_REFERENCE.md` | Command reference and cheat sheet |
| `DEPLOYMENT_CHECKLIST.md` | Step-by-step deployment checklist |
| `WORKFLOW_DIAGRAMS.md` | Visual workflow diagrams |
| `IMPLEMENTATION_SUMMARY.md` | Overview of CI/CD features |

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
