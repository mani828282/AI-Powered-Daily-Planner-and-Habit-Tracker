# Habit Tracker App - Deployment Quick Reference

## Your Server Details (Fill these in after setup)

```
Droplet IP: _________________
Root Password: _________________
Database Password: _________________
Domain (if any): _________________
```

## Quick Commands

### Connect to Server
```bash
ssh root@YOUR_DROPLET_IP
```

### Check Backend Status
```bash
sudo systemctl status habit-tracker
```

### View Backend Logs
```bash
sudo journalctl -u habit-tracker -f
```

### Restart Backend
```bash
sudo systemctl restart habit-tracker
```

### Check Database
```bash
mysql -u appuser -p ai_planner_db
```

### Update Code from GitHub
```bash
cd /home/appuser/habit-tracker-app
git pull origin main
sudo systemctl restart habit-tracker
```

### Backup Database
```bash
mysqldump -u appuser -p ai_planner_db > backup_$(date +%Y%m%d).sql
```

## API Endpoints

- Health Check: `http://YOUR_IP/health`
- API Base: `http://YOUR_IP/api`
- With SSL: `https://yourdomain.com/api`

## Troubleshooting

**Backend not responding:**
```bash
sudo systemctl restart habit-tracker
sudo systemctl restart nginx
```

**Database issues:**
```bash
sudo systemctl restart mysql
```

**Check disk space:**
```bash
df -h
```

**Check memory:**
```bash
free -h
```

## Important Files

- Backend code: `/home/appuser/habit-tracker-app/backend/`
- Environment: `/home/appuser/habit-tracker-app/backend/.env`
- Nginx config: `/etc/nginx/sites-available/habit-tracker`
- Service file: `/etc/systemd/system/habit-tracker.service`
- Logs: `/var/log/nginx/` and `sudo journalctl -u habit-tracker`

## Monthly Maintenance

1. Update system: `sudo apt update && sudo apt upgrade -y`
2. Check disk space: `df -h`
3. Review logs for errors
4. Verify backups are running
5. Test all features on mobile app
