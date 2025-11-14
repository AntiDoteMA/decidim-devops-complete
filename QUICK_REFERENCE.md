# CI/CD Quick Reference

## 🎯 Quick Commands

### GitLab Runner Management
```bash
# Install GitLab Runner
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install gitlab-runner

# Register Runner
sudo gitlab-runner register
# Use tag: decidim-production

# Setup permissions
sudo usermod -aG docker gitlab-runner
sudo gitlab-runner restart

# Check status
sudo gitlab-runner status
```

### Deployment Workflow
```bash
# 1. Make changes
git add .
git commit -m "Your changes"
git push origin main

# 2. Go to GitLab and manually trigger:
#    CI/CD → Pipelines → deploy_production

# 3. Monitor logs in GitLab UI
```

### Manual Operations
```bash
# View logs
cd /opt/decidim
docker compose logs -f decidim

# Restart services
docker compose restart

# Check status
docker compose ps

# Manual backup
bash backup.sh

# Manual restore
bash restore.sh backups/2024-01-15/
```

## 🔧 Pipeline Jobs

| Job | Trigger | Purpose |
|-----|---------|---------|
| `validate_config` | Automatic | Validates all config files |
| `deploy_production` | Manual | Deploys to production |
| `backup_after_deploy` | Auto (after deploy) | Creates backup |
| `rollback` | Manual | Reverts to previous backup |
| `view_logs` | Manual | Shows application logs |
| `health_check` | Manual | Runs health diagnostics |
| `scheduled_backup` | Scheduled | Daily automated backup |

## ⚠️ Important Notes

- **Production deployments require manual trigger** (safety feature)
- **Backups are kept for 7 days** automatically
- **Rollback restores the previous backup** (not just code)
- **Health checks should run weekly** minimum
- **SSL certificates auto-renew** via Certbot

## 🐛 Common Issues

### Runner not found
```bash
sudo gitlab-runner restart
```

### Docker permission denied
```bash
sudo usermod -aG docker gitlab-runner
sudo gitlab-runner restart
```

### Service not responding
```bash
cd /opt/decidim
docker compose restart decidim
docker compose logs decidim
```

### Disk space issues
```bash
# Clean old Docker images
docker system prune -a

# Check backup space
du -sh /opt/decidim/backups/*

# Remove old backups manually if needed
rm -rf /opt/decidim/backups/2024-01-01*
```

## 📞 Emergency Procedures

### Complete Service Restart
```bash
cd /opt/decidim
docker compose down
docker compose up -d
```

### Emergency Rollback
```bash
# Via GitLab: Trigger 'rollback' job
# Or manually:
cd /opt/decidim
bash restore.sh backups/$(ls -t backups/ | head -2 | tail -1)
docker compose restart
```

### Check Everything is Working
```bash
# Via GitLab: Trigger 'health_check' job
# Or manually:
curl http://localhost:3000/
docker compose ps
systemctl status nginx
```

## 📊 Monitoring Checklist

- [ ] Check GitLab pipeline status weekly
- [ ] Review health_check output weekly
- [ ] Verify backups are being created
- [ ] Check SSL certificate expiry monthly
- [ ] Monitor disk space usage
- [ ] Review application logs for errors

## 🔐 Security Checklist

- [ ] GitLab CI/CD variables marked as protected
- [ ] SMTP credentials stored securely
- [ ] Server firewall configured (UFW)
- [ ] SSH key-based authentication only
- [ ] Regular security updates applied
- [ ] Backup encryption considered

---

For detailed documentation, see [CICD_SETUP.md](CICD_SETUP.md)
