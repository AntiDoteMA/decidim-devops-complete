# GitLab CI/CD Setup Guide

This guide explains how to set up and use the GitLab CI/CD pipeline for automated Decidim deployments.

---

## 📋 Prerequisites

### 1. GitLab Runner Setup
You need a GitLab Runner installed on your production server.

#### Install GitLab Runner on Ubuntu 22.04:
```bash
# Download the official GitLab repository installation script
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash

# Install the latest version of GitLab Runner
sudo apt-get install gitlab-runner

# Verify installation
gitlab-runner --version
```

#### Register the Runner:
```bash
sudo gitlab-runner register
```

When prompted, provide:
- **GitLab instance URL**: `https://gitlab.com/` (or your GitLab server)
- **Registration token**: Get from your GitLab project → Settings → CI/CD → Runners
- **Description**: `decidim-production`
- **Tags**: `decidim-production` (important - matches the pipeline)
- **Executor**: `shell`

#### Grant Runner permissions:
```bash
# Add gitlab-runner user to docker group
sudo usermod -aG docker gitlab-runner

# Grant sudo permissions (needed for Nginx operations)
sudo visudo
# Add this line:
# gitlab-runner ALL=(ALL) NOPASSWD: ALL

# Restart runner
sudo gitlab-runner restart
```

### 2. Server Prerequisites
Ensure your server has:
- Docker & Docker Compose installed
- Nginx installed
- Ports 80 and 443 open
- Domain DNS configured

---

## 🚀 CI/CD Pipeline Overview

### Stages:
1. **validate** - Validates configuration files
2. **deploy** - Deploys to production (manual trigger)
3. **backup** - Creates automated backups
4. **monitor** - Health checks and logs

### Jobs:

#### `validate_config`
- Runs on all branches
- Validates `docker-compose.yml` syntax
- Checks for required files
- Automatic trigger

#### `deploy_production`
- Runs on `main` branch only
- Manual trigger required (safety measure)
- Deploys latest version to production
- Updates Nginx configuration
- Performs health checks

#### `backup_after_deploy`
- Runs automatically after successful deployment
- Backs up database, uploads, and configuration
- Keeps last 7 days of backups
- Creates deployment metadata

#### `rollback`
- Manual trigger only
- Restores from most recent backup
- Useful for reverting bad deployments

#### `view_logs`
- Manual trigger
- Shows last 100 lines of application logs
- Displays container status

#### `health_check`
- Manual trigger
- Comprehensive health monitoring
- Checks all services (Decidim, PostgreSQL, Redis, Nginx)
- SSL certificate validation
- Disk and memory usage

#### `scheduled_backup`
- Triggered by GitLab CI/CD schedules
- Daily automated backups

---

## 🔧 Configuration

### Environment Variables
Configure these in GitLab: **Project Settings → CI/CD → Variables**

| Variable | Description | Example |
|----------|-------------|---------|
| `SMTP_ADDRESS` | Email server address | `smtp.gmail.com` |
| `SMTP_PORT` | Email server port | `587` |
| `SMTP_USERNAME` | Email username | `noreply@example.com` |
| `SMTP_PASSWORD` | Email password | `your_password` |

**Note**: Mark sensitive variables as "Protected" and "Masked"

### Domain Configuration
Edit `.gitlab-ci.yml` variables:
```yaml
variables:
  DOMAIN: "decidev.DOMAIN_NAME.ext"  # Change to your domain
  EMAIL: "admin@DOMAIN_NAME.ext"     # Change to your email
  INSTALL_DIR: "/opt/decidim"      # Installation directory
```

---

## 📖 Usage Guide

### First-Time Deployment

1. **Push code to main branch:**
   ```bash
   git add .
   git commit -m "Initial deployment"
   git push origin main
   ```

2. **Trigger deployment:**
   - Go to GitLab: **CI/CD → Pipelines**
   - Click on the pipeline
   - Manually trigger the `deploy_production` job
   - Monitor the deployment logs

3. **Setup SSL (first time only):**
   ```bash
   # SSH to your server
   sudo certbot --nginx -d decidev.DOMAIN_NAME.ext
   ```

4. **Verify deployment:**
   - Manually trigger the `health_check` job
   - Visit your domain: `https://decidev.DOMAIN_NAME.ext`

### Regular Deployments

1. Make changes to your code
2. Commit and push to `main` branch
3. Go to GitLab pipelines
4. Manually trigger `deploy_production`
5. Automatic backup runs after successful deployment

### Rollback Procedure

If a deployment fails or causes issues:

1. Go to GitLab: **CI/CD → Pipelines**
2. Find the pipeline
3. Manually trigger the `rollback` job
4. Monitor the rollback process
5. Verify with `health_check` job

### View Application Logs

1. Go to GitLab pipelines
2. Manually trigger `view_logs` job
3. Or SSH to server and run:
   ```bash
   cd /opt/decidim
   docker compose logs -f decidim
   ```

### Manual Health Check

1. Go to GitLab pipelines
2. Manually trigger `health_check` job
3. Review all service statuses

---

## 🕐 Scheduled Backups

### Setup Daily Automated Backups:

1. Go to **GitLab → CI/CD → Schedules**
2. Click **New schedule**
3. Configure:
   - **Description**: Daily Decidim Backup
   - **Interval Pattern**: `0 2 * * *` (2 AM daily)
   - **Cron Timezone**: Your timezone
   - **Target Branch**: `main`
   - **Variables**: (none needed)
4. Click **Save pipeline schedule**

### Manual Backup:
```bash
# SSH to server
cd /opt/decidim
bash backup.sh
```

### Restore from Backup:
```bash
# SSH to server
cd /opt/decidim
bash restore.sh backups/2024-01-15_02-00-00/
```

---

## 🔍 Troubleshooting

### Pipeline Fails at Deploy Stage

**Issue**: `gitlab-runner: command not found`
- **Solution**: Runner not installed. Follow GitLab Runner setup steps above.

**Issue**: `permission denied: docker`
- **Solution**: Add gitlab-runner to docker group:
  ```bash
  sudo usermod -aG docker gitlab-runner
  sudo gitlab-runner restart
  ```

**Issue**: `cannot connect to docker daemon`
- **Solution**: Start Docker service:
  ```bash
  sudo systemctl start docker
  sudo systemctl enable docker
  ```

### Health Check Failures

**Issue**: Decidim not responding
- Check logs: `docker compose logs decidim`
- Restart: `docker compose restart decidim`

**Issue**: PostgreSQL not healthy
- Check database: `docker exec decidim-db pg_isready -U decidim`
- Check logs: `docker compose logs postgres`

**Issue**: SSL certificate not found
- Run Certbot manually: `sudo certbot --nginx -d your-domain.com`

### Rollback Issues

**Issue**: No backup found
- Ensure at least one successful deployment completed
- Check backups directory: `ls -la /opt/decidim/backups/`

---

## 📊 Monitoring

### Check Pipeline Status
- GitLab: **CI/CD → Pipelines**
- View job logs
- Download artifacts if configured

### Server Monitoring
```bash
# Container status
cd /opt/decidim
docker compose ps

# Resource usage
docker stats

# Disk space
df -h /opt/decidim

# Recent logs
docker compose logs --tail=50 decidim
```

### Application Monitoring
- Access admin panel: `https://your-domain.com/admin`
- Check application health: `https://your-domain.com/`
- Monitor error logs in GitLab pipeline jobs

---

## 🔐 Security Best Practices

1. **Protect sensitive variables** in GitLab CI/CD settings
2. **Use SSH keys** for server access (not passwords)
3. **Regularly update** Docker images: `docker compose pull`
4. **Monitor SSL expiry** - Certbot auto-renews, but check:
   ```bash
   sudo certbot certificates
   ```
5. **Restrict GitLab Runner** permissions where possible
6. **Keep backups secure** - consider offsite backup storage

---

## 📝 Notes

- **Manual triggers** on production jobs prevent accidental deployments
- **Automatic backups** run after each successful deployment
- **7-day backup retention** prevents disk space issues
- **Health checks** should be run regularly (weekly recommended)
- **Scheduled backups** complement deployment backups

---

## 🆘 Support

### Useful Commands

```bash
# Check runner status
sudo gitlab-runner status

# Restart runner
sudo gitlab-runner restart

# View runner logs
sudo journalctl -u gitlab-runner -f

# Test docker access
sudo -u gitlab-runner docker ps

# Test Nginx config
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

### Common GitLab CI/CD URLs
- Pipeline list: `https://gitlab.com/your-username/your-project/-/pipelines`
- CI/CD settings: `https://gitlab.com/your-username/your-project/-/settings/ci_cd`
- Runners: `https://gitlab.com/your-username/your-project/-/settings/ci_cd#js-runners-settings`
- Schedules: `https://gitlab.com/your-username/your-project/-/pipeline_schedules`

---

Made with 💡 by the DevOps team
