# CI/CD Workflow Diagrams

## Deployment Flow

```
Developer                GitLab                 Production Server
    |                       |                           |
    | git push origin main  |                           |
    |---------------------->|                           |
    |                       |                           |
    |                       | 1. validate_config        |
    |                       |    (automatic)            |
    |                       |--------                   |
    |                       |       | Check syntax      |
    |                       |<-------                   |
    |                       |                           |
    | Manual trigger        |                           |
    | deploy_production     |                           |
    |---------------------->|                           |
    |                       |                           |
    |                       | 2. deploy_production      |
    |                       |-------------------------->|
    |                       |    Copy files             |
    |                       |    Generate secrets       |
    |                       |    Pull images            |
    |                       |    Stop/Start services    |
    |                       |    Health checks          |
    |                       |<--------------------------|
    |                       |         Success ✓         |
    |                       |                           |
    |                       | 3. backup_after_deploy    |
    |                       |    (automatic)            |
    |                       |-------------------------->|
    |                       |    Backup DB              |
    |                       |    Backup uploads         |
    |                       |    Save metadata          |
    |                       |<--------------------------|
    |                       |         Done ✓            |
    |<----------------------|                           |
    |   Deployment Complete |                           |
    |                       |                           |
```

## Health Check Flow

```
┌──────────────┐
│  Trigger     │
│ health_check │
└──────┬───────┘
       │
       ▼
┌──────────────────────────┐
│ Check Docker Containers  │
│ ✓ decidim                │
│ ✓ postgres               │
│ ✓ redis                  │
│ ✓ nginx                  │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│ Check Service Health     │
│ ✓ App responding         │
│ ✓ DB accepting queries   │
│ ✓ Redis ping success     │
│ ✓ Nginx running          │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│ Check SSL Certificate    │
│ ✓ Certificate exists     │
│ ✓ Not expired            │
│ ⚠ Expires in 30 days     │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│ Check System Resources   │
│ ✓ Disk: 45% used         │
│ ✓ Memory: 2.5GB/4GB      │
│ ✓ Backups: 5 available   │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│   Report Results         │
│   All Systems OK ✓       │
└──────────────────────────┘
```

## Rollback Flow

```
    Problem Detected
           │
           ▼
    ┌──────────────┐
    │   Trigger    │
    │   Rollback   │
    └──────┬───────┘
           │
           ▼
    ┌──────────────────┐
    │ Find Last Backup │
    │ backups/         │
    │ 2024-01-15/      │◄── Most recent
    └──────┬───────────┘
           │
           ▼
    ┌──────────────────┐
    │ Stop Services    │
    └──────┬───────────┘
           │
           ▼
    ┌──────────────────┐
    │ Restore Database │
    │ pg_dump restore  │
    └──────┬───────────┘
           │
           ▼
    ┌──────────────────┐
    │ Restore Uploads  │
    │ Copy files       │
    └──────┬───────────┘
           │
           ▼
    ┌──────────────────┐
    │ Start Services   │
    └──────┬───────────┘
           │
           ▼
    ┌──────────────────┐
    │ Verify Health    │
    │ curl localhost   │
    └──────┬───────────┘
           │
           ▼
    ┌──────────────────┐
    │ Rollback Done ✓  │
    └──────────────────┘
```

## Backup Strategy

```
┌─────────────────────────────────────────────┐
│           Backup Schedule                    │
└─────────────────────────────────────────────┘

Post-Deployment Backups
└── Triggered after each successful deployment
    ├── Database dump
    ├── Uploads folder
    ├── Configuration files
    └── Deployment metadata

Scheduled Daily Backups
└── 2:00 AM every day (configurable)
    ├── Database dump
    ├── Uploads folder
    └── Timestamp in filename

Manual Backups
└── Run anytime via backup.sh
    ├── On-demand backups
    └── Before major changes

┌─────────────────────────────────────────────┐
│        Backup Retention Policy              │
└─────────────────────────────────────────────┘

Day 1-7:  All backups kept
Day 8+:   Automatically deleted

Example:
backups/
├── 2024-01-15_02-00-00_post_deploy/  ✓ Keep
├── 2024-01-14_02-00-00/              ✓ Keep
├── 2024-01-13_14-30-00_manual/       ✓ Keep
├── 2024-01-10_02-00-00/              ✓ Keep
├── 2024-01-05_02-00-00/              ✗ Delete
└── 2024-01-01_02-00-00/              ✗ Delete
```

## CI/CD Stages Overview

```
┌───────────────────────────────────────────────────────┐
│                    CI/CD Pipeline                      │
└───────────────────────────────────────────────────────┘

Stage 1: VALIDATE
├── validate_config ────────► Automatic on all branches
│   ├── Syntax check
│   ├── File existence
│   └── Configuration validation

Stage 2: DEPLOY
├── deploy_production ──────► Manual trigger (main only)
│   ├── Setup environment
│   ├── Pull images
│   ├── Deploy services
│   └── Health verification
│
└── rollback ───────────────► Manual trigger (emergency)
    ├── Find backup
    ├── Stop services
    ├── Restore data
    └── Restart services

Stage 3: BACKUP
├── backup_after_deploy ────► Automatic after deploy
│   ├── Backup database
│   ├── Backup uploads
│   ├── Save metadata
│   └── Cleanup old
│
└── scheduled_backup ───────► GitLab schedule (daily)
    └── Uses backup.sh script

Stage 4: MONITOR
├── health_check ───────────► Manual trigger
│   ├── Service status
│   ├── SSL certificate
│   ├── System resources
│   └── Backup inventory
│
└── view_logs ──────────────► Manual trigger
    ├── Recent logs
    └── Container status
```

## Infrastructure Overview

```
                    Internet
                       │
                       │ HTTPS/443
                       │ HTTP/80
                       ▼
              ┌────────────────┐
              │     Nginx      │
              │ (Reverse Proxy)│
              └────────┬───────┘
                       │
                       │ Port 3000
                       ▼
              ┌────────────────┐
              │    Decidim     │◄─────┐
              │   Application  │      │
              └────────┬───────┘      │
                       │              │
              ┌────────┴────────┐     │
              │                 │     │
              ▼                 ▼     │
     ┌────────────────┐ ┌─────────────┐
     │   PostgreSQL   │ │    Redis    │
     │   Database     │ │    Cache    │
     └────────────────┘ └─────────────┘
              │
              │ (volumes)
              ▼
     ┌────────────────┐
     │   Host Storage │
     ├────────────────┤
     │ postgres-data/ │
     │ redis-data/    │
     │ uploads/       │
     │ backups/       │
     └────────────────┘
```

## Security Layers

```
┌─────────────────────────────────────────────┐
│              Security Stack                  │
└─────────────────────────────────────────────┘

Layer 1: Network
├── Firewall (UFW)
│   ├── Port 80  (HTTP)  ✓
│   ├── Port 443 (HTTPS) ✓
│   └── Port 22  (SSH)   ✓
└── SSL/TLS (Let's Encrypt)
    ├── Auto-renewal
    └── Strong ciphers

Layer 2: Application
├── Environment Variables
│   ├── Secrets in .env
│   ├── Not in Git
│   └── Protected in GitLab
└── Session Management
    ├── Secure cookies
    └── CSRF protection

Layer 3: Data
├── Database
│   ├── Strong password
│   ├── Internal network only
│   └── Regular backups
└── File Storage
    ├── Restricted permissions
    └── Upload size limits

Layer 4: CI/CD
├── Manual Deploy Trigger
│   └── Prevents accidents
├── Protected Variables
│   └── Encrypted in GitLab
└── Runner Permissions
    └── Minimal required access
```

## Monitoring & Alerting

```
┌─────────────────────────────────────────────┐
│          Monitoring Points                   │
└─────────────────────────────────────────────┘

Application Level
├── HTTP Response (localhost:3000)
├── Container Health
└── Application Logs

Database Level
├── PostgreSQL Status
├── Connection Pool
└── Query Performance

Infrastructure Level
├── Disk Space (>85% = warning)
├── Memory Usage
├── CPU Usage
└── Network I/O

Security Level
├── SSL Certificate Expiry
├── Failed Login Attempts
├── Suspicious Activity
└── Backup Completion

GitLab Integration
├── Pipeline Status
├── Deploy Success/Failure
├── Backup Verification
└── Health Check Results
```

---

## Quick Reference Symbols

```
✓  Success / OK
✗  Failed / Error
⚠  Warning / Attention Needed
│  Flow continues
►  Process / Action
◄  Return / Response
```

---

For more details, see:
- **CICD_SETUP.md** - Complete setup guide
- **QUICK_REFERENCE.md** - Command reference
- **IMPLEMENTATION_SUMMARY.md** - Feature overview
