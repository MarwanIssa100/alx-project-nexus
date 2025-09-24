# PostgreSQL Deployment Guide

## Current Setup Analysis

Your project is already configured with PostgreSQL in Docker Compose. Here are your deployment options:

## 1. Docker Compose Deployment (Current Setup)

### Quick Start
```bash
# Start all services
docker-compose up -d

# Check PostgreSQL status
docker-compose ps db

# View PostgreSQL logs
docker-compose logs db
```

### Environment Variables
Create a `.env` file in your project root:
```env
# Database Configuration
USE_POSTGRES=True
DB_NAME=poll_system_db
DB_USER=postgres
DB_PASSWORD=your_secure_password
DB_HOST=db
DB_PORT=5432

# Security
SECRET_KEY=your-django-secret-key
DEBUG=False
ALLOWED_HOSTS=your-domain.com,localhost

# Redis Configuration
REDIS_URL=redis://redis:6379/1
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0
```

## 2. Production Deployment Options

### Option A: Managed Database Services

#### AWS RDS
```yaml
# Update docker-compose.prod.yml
services:
  web:
    environment:
      - DB_HOST=your-rds-endpoint.amazonaws.com
      - DB_NAME=poll_system_prod
      - DB_USER=your_rds_user
      - DB_PASSWORD=your_rds_password
      - DB_PORT=5432
```

#### Google Cloud SQL
```yaml
# For Google Cloud SQL
services:
  web:
    environment:
      - DB_HOST=/cloudsql/your-project:region:instance
      - DB_NAME=poll_system_prod
      - DB_USER=your_sql_user
      - DB_PASSWORD=your_sql_password
```

#### DigitalOcean Managed Database
```yaml
# For DigitalOcean
services:
  web:
    environment:
      - DB_HOST=your-db-cluster.db.ondigitalocean.com
      - DB_NAME=poll_system_prod
      - DB_USER=your_db_user
      - DB_PASSWORD=your_db_password
      - DB_PORT=25060
```

### Option B: Self-Managed PostgreSQL

#### Using Docker on VPS
```bash
# Create production docker-compose
cp docker-compose.yml docker-compose.prod.yml

# Update for production
# - Change passwords
# - Add SSL configuration
# - Configure backup volumes
# - Set resource limits
```

#### Traditional Installation
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install postgresql postgresql-contrib

# Create database and user
sudo -u postgres psql
CREATE DATABASE poll_system_prod;
CREATE USER poll_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE poll_system_prod TO poll_user;
```

## 3. Database Migration Strategy

### From SQLite to PostgreSQL
```bash
# 1. Backup current SQLite data
python manage.py dumpdata --natural-foreign --natural-primary > backup.json

# 2. Update settings to use PostgreSQL
# Set USE_POSTGRES=True in .env

# 3. Run migrations
python manage.py migrate

# 4. Load data (if needed)
python manage.py loaddata backup.json
```

### Database Backup and Restore
```bash
# Backup
docker-compose exec db pg_dump -U postgres poll_system_db > backup.sql

# Restore
docker-compose exec -T db psql -U postgres poll_system_db < backup.sql
```

## 4. Security Best Practices

### Environment Variables
- Never commit passwords to version control
- Use strong, unique passwords
- Rotate credentials regularly
- Use environment-specific configurations

### Database Security
```sql
-- Create read-only user for reporting
CREATE USER poll_readonly WITH PASSWORD 'readonly_password';
GRANT CONNECT ON DATABASE poll_system_db TO poll_readonly;
GRANT USAGE ON SCHEMA public TO poll_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO poll_readonly;
```

### SSL Configuration
```yaml
# In docker-compose.yml
services:
  db:
    environment:
      POSTGRES_SSL_MODE: require
    command: >
      postgres
      -c ssl=on
      -c ssl_cert_file=/var/lib/postgresql/server.crt
      -c ssl_key_file=/var/lib/postgresql/server.key
```

## 5. Monitoring and Maintenance

### Health Checks
```bash
# Check database connectivity
docker-compose exec web python manage.py dbshell

# Check database size
docker-compose exec db psql -U postgres -c "SELECT pg_size_pretty(pg_database_size('poll_system_db'));"
```

### Performance Monitoring
```sql
-- Check active connections
SELECT count(*) FROM pg_stat_activity;

-- Check slow queries
SELECT query, mean_time, calls 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;
```

## 6. Scaling Considerations

### Read Replicas
```yaml
# Add read replica
services:
  db-replica:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: poll_system_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    command: >
      postgres
      -c hot_standby=on
      -c primary_conninfo='host=db port=5432 user=postgres'
```

### Connection Pooling
```python
# Add to requirements.txt
psycopg2-pool==1.1

# Update settings.py
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DB_NAME'),
        'USER': config('DB_USER'),
        'PASSWORD': config('DB_PASSWORD'),
        'HOST': config('DB_HOST'),
        'PORT': config('DB_PORT'),
        'OPTIONS': {
            'MAX_CONNS': 20,
            'MIN_CONNS': 5,
        }
    }
}
```

## Next Steps

1. **Choose your deployment method** based on your needs
2. **Set up environment variables** securely
3. **Test the deployment** in a staging environment
4. **Configure monitoring** and backups
5. **Plan for scaling** as your application grows

## Quick Commands Reference

```bash
# Start PostgreSQL
docker-compose up -d db

# Connect to database
docker-compose exec db psql -U postgres -d poll_system_db

# Run migrations
docker-compose exec web python manage.py migrate

# Create superuser
docker-compose exec web python manage.py createsuperuser

# Backup database
docker-compose exec db pg_dump -U postgres poll_system_db > backup.sql

# View logs
docker-compose logs -f db
```
