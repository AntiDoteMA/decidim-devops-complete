# Decidim Deployment Checklist

Use this checklist to ensure a smooth deployment of your Decidim instance with CI/CD.

---

## 📋 Pre-Deployment Checklist

### Server Setup
- [ ] Ubuntu 22.04 server provisioned
- [ ] Root or sudo access available
- [ ] Server has at least 2GB RAM (4GB recommended)
- [ ] Server has at least 20GB disk space (50GB+ recommended)
- [ ] SSH access configured with key-based authentication

### Network & DNS
- [ ] Domain name purchased and configured
- [ ] DNS A record pointing to server IP
  ```bash
  # Verify with:
  host decidev.DOMAIN_NAME.ext
  ```
- [ ] Firewall ports opened:
  - [ ] Port 80 (HTTP)
  - [ ] Port 443 (HTTPS)
  - [ ] Port 22 (SSH)
  ```bash
  # For UFW:
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  sudo ufw allow 22/tcp
  sudo ufw enable
  ```

### Software Installation
- [ ] Docker installed
  ```bash
  docker --version
  # Should show: Docker version 20.x or higher
  ```
- [ ] Docker Compose installed
  ```bash
  docker compose version
  # Should show: Docker Compose version v2.x
  ```
- [ ] Nginx installed
  ```bash
  nginx -v
  # Should show: nginx version 1.x
  ```
- [ ] Certbot installed
  ```bash
  certbot --version
  # Should show: certbot 1.x or higher
  ```
- [ ] Git installed
  ```bash
  git --version
  ```

---

## 🔧 GitLab Configuration

### Repository Setup
- [ ] GitLab repository created
- [ ] Repository cloned to local machine
- [ ] All files committed and pushed
  ```bash
  git remote -v
  # Should show your GitLab repository
  ```

### GitLab Runner
- [ ] GitLab Runner installed on server
  ```bash
  gitlab-runner --version
  ```
- [ ] Runner registered with tag `decidim-production`
  ```bash
  sudo gitlab-runner list
  # Should show your runner
  ```
- [ ] Runner has Docker permissions
  ```bash
  sudo usermod -aG docker gitlab-runner
  ```
- [ ] Runner service is running
  ```bash
  sudo gitlab-runner status
  # Should show: Service is running
  ```

### CI/CD Variables (GitLab → Settings → CI/CD → Variables)
- [ ] `SMTP_ADDRESS` set (if using email)
- [ ] `SMTP_PORT` set (if using email)
- [ ] `SMTP_USERNAME` set (if using email)
- [ ] `SMTP_PASSWORD` set and marked as **Masked** and **Protected**
- [ ] All sensitive variables marked as **Protected** and **Masked**

---

## 📝 Configuration Files

### Update Domain Names
- [ ] `.gitlab-ci.yml` - Update `DOMAIN` variable (line 5)
  ```yaml
  DOMAIN: "decidev.DOMAIN_NAME.ext"  # ← Change this
  ```
- [ ] `.gitlab-ci.yml` - Update `EMAIL` variable (line 6)
  ```yaml
  EMAIL: "admin@DOMAIN_NAME.ext"    # ← Change this
  ```
- [ ] `.env.example` - Update domain references
  ```bash
  DECIDIM_HOST=decidev.DOMAIN_NAME.ext    # ← Change this
  DOMAIN_NAME=decidev.DOMAIN_NAME.ext     # ← Change this
  ```
- [ ] `docker-compose.yml` - Review and confirm settings
- [ ] `nginx.conf` - Review and confirm settings

### Generate Secrets (Optional - CI/CD can do this)
- [ ] Generate `SECRET_KEY_BASE`
  ```bash
  openssl rand -hex 64
  ```
- [ ] Generate `POSTGRES_PASSWORD`
  ```bash
  openssl rand -hex 32
  ```

---

## 🚀 First Deployment

### Pre-Flight Check
- [ ] All changes committed to Git
  ```bash
  git status
  # Should show: nothing to commit, working tree clean
  ```
- [ ] Working on `main` branch
  ```bash
  git branch
  # Should show: * main
  ```

### Deploy Steps
- [ ] Push to GitLab
  ```bash
  git push origin main
  ```
- [ ] Go to **GitLab → CI/CD → Pipelines**
- [ ] Verify `validate_config` job passes (automatic)
- [ ] Manually trigger `deploy_production` job
- [ ] Monitor deployment logs in GitLab
- [ ] Wait for deployment to complete (5-10 minutes)
- [ ] Verify `backup_after_deploy` runs automatically

### SSL Certificate Setup
- [ ] SSH to server
- [ ] Run Certbot
  ```bash
  sudo certbot --nginx -d decidev.DOMAIN_NAME.ext
  ```
- [ ] Verify SSL certificate obtained
  ```bash
  sudo certbot certificates
  ```
- [ ] Test HTTPS access
  ```bash
  curl -I https://decidev.DOMAIN_NAME.ext
  # Should show: HTTP/2 200
  ```

---

## ✅ Post-Deployment Verification

### Service Health Checks
- [ ] Trigger `health_check` job in GitLab
- [ ] All services show as healthy
- [ ] SSL certificate valid
- [ ] Disk space adequate

### Application Access
- [ ] Access site via HTTP
  ```
  http://decidev.DOMAIN_NAME.ext
  ```
- [ ] Access site via HTTPS (after SSL setup)
  ```
  https://decidev.DOMAIN_NAME.ext
  ```
- [ ] Application loads without errors
- [ ] Can access admin panel
  ```
  https://decidev.DOMAIN_NAME.ext/admin
  ```

### Docker Containers
- [ ] All containers running
  ```bash
  cd /opt/decidim
  docker compose ps
  # Should show all services as "Up"
  ```
- [ ] No restart loops
  ```bash
  docker compose ps
  # "Status" should not show constant restarts
  ```
- [ ] Logs show no critical errors
  ```bash
  docker compose logs --tail=50
  ```

### Database
- [ ] PostgreSQL accessible
  ```bash
  docker exec decidim-db pg_isready -U decidim
  # Should show: accepting connections
  ```
- [ ] Database created
  ```bash
  docker exec decidim-db psql -U decidim -l
  # Should list decidim_production
  ```

### File Storage
- [ ] Uploads directory created
  ```bash
  ls -la /opt/decidim/uploads
  ```
- [ ] Correct permissions set
  ```bash
  ls -ld /opt/decidim
  # Should show appropriate ownership
  ```

---

## 📅 Ongoing Maintenance Setup

### Scheduled Backups
- [ ] Go to **GitLab → CI/CD → Schedules**
- [ ] Create new schedule
  - **Description**: Daily Decidim Backup
  - **Interval Pattern**: `0 2 * * *` (2 AM daily)
  - **Target Branch**: `main`
- [ ] Schedule active and enabled
- [ ] Test schedule by running manually
- [ ] Verify backup created in `/opt/decidim/backups/`

### Monitoring Setup
- [ ] Add health check to monitoring system (if available)
- [ ] Setup alerts for deployment failures
- [ ] Document escalation procedures

### SSL Auto-Renewal
- [ ] Verify Certbot auto-renewal configured
  ```bash
  sudo systemctl status certbot.timer
  # Should show: active
  ```
- [ ] Test renewal process
  ```bash
  sudo certbot renew --dry-run
  ```

---

## 🔐 Security Hardening

### Server Security
- [ ] SSH password authentication disabled
- [ ] SSH key-based authentication only
- [ ] Firewall (UFW) enabled and configured
- [ ] Fail2ban installed (optional but recommended)
  ```bash
  sudo apt install fail2ban
  sudo systemctl enable fail2ban
  ```

### Application Security
- [ ] Default passwords changed in `.env`
- [ ] Strong `SECRET_KEY_BASE` generated
- [ ] Strong `POSTGRES_PASSWORD` generated
- [ ] SMTP credentials secured in GitLab variables

### Backup Security
- [ ] Backup directory permissions restricted
  ```bash
  chmod 700 /opt/decidim/backups
  ```
- [ ] Consider offsite backup replication
- [ ] Test restore procedure

---

## 📚 Documentation Review

### Team Knowledge
- [ ] Team knows how to trigger deployments
- [ ] Team knows how to view logs
- [ ] Team knows rollback procedure
- [ ] Emergency contacts documented

### Documentation Access
- [ ] `README.md` reviewed
- [ ] `CICD_SETUP.md` read by ops team
- [ ] `QUICK_REFERENCE.md` bookmarked
- [ ] `WORKFLOW_DIAGRAMS.md` reviewed

---

## 🧪 Testing Checklist

### Deployment Testing
- [ ] Test deployment to verify it works
- [ ] Test rollback procedure
- [ ] Test manual backup
- [ ] Test restore from backup

### Application Testing
- [ ] Create test user account
- [ ] Test login functionality
- [ ] Test basic features
- [ ] Test admin panel access
- [ ] Test file uploads (if applicable)

### Monitoring Testing
- [ ] Trigger health check job
- [ ] Review all health check outputs
- [ ] Test log viewing
- [ ] Verify backup creation

---

## 📊 Success Criteria

Your deployment is successful when:

- ✅ Application accessible via HTTPS
- ✅ All Docker containers running without restart loops
- ✅ Database accepting connections
- ✅ SSL certificate valid and auto-renewing
- ✅ Backups being created automatically
- ✅ Health checks passing
- ✅ GitLab CI/CD pipeline working
- ✅ Rollback procedure tested and working
- ✅ Team trained on deployment procedures
- ✅ Documentation complete and accessible

---

## 🆘 Troubleshooting Quick Links

If something goes wrong:

1. **Check Pipeline Logs**: GitLab → CI/CD → Pipelines → Job logs
2. **Check Application Logs**: Trigger `view_logs` job
3. **Run Health Check**: Trigger `health_check` job
4. **SSH to Server**: `ssh user@server` and run `docker compose logs`
5. **Consult Documentation**: See `CICD_SETUP.md` troubleshooting section

---

## 📞 Emergency Contacts

Document your team's emergency contacts:

- **DevOps Lead**: ___________________________
- **System Administrator**: ___________________________
- **On-Call Engineer**: ___________________________
- **Escalation Contact**: ___________________________

---

## ✅ Sign-Off

- [ ] All checklist items completed
- [ ] Deployment verified in production
- [ ] Team trained and ready
- [ ] Documentation reviewed and approved

**Deployed By**: ___________________________
**Date**: ___________________________
**Signature**: ___________________________

---

**Congratulations! Your Decidim instance is ready for production!** 🎉
