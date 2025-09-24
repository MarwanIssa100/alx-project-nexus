# PostgreSQL Deployment Script for Windows PowerShell
# This script helps deploy PostgreSQL for the poll system

param(
    [Parameter(Position=0)]
    [ValidateSet("deploy", "status", "logs", "stop", "restart", "backup", "help")]
    [string]$Command = "deploy"
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$White = "White"

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $Red
}

# Check if Docker is installed
function Test-Docker {
    try {
        docker --version | Out-Null
        Write-Status "Docker is installed"
        return $true
    }
    catch {
        Write-Error "Docker is not installed. Please install Docker Desktop first."
        return $false
    }
}

# Check if Docker Compose is installed
function Test-DockerCompose {
    try {
        docker-compose --version | Out-Null
        Write-Status "Docker Compose is installed"
        return $true
    }
    catch {
        Write-Error "Docker Compose is not installed. Please install Docker Compose first."
        return $false
    }
}

# Create .env file if it doesn't exist
function New-EnvFile {
    if (-not (Test-Path ".env")) {
        Write-Warning ".env file not found. Creating from template..."
        
        # Generate random passwords
        $dbPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
        $secretKey = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 50 | ForEach-Object {[char]$_})
        
        $envContent = @"
# Database Configuration
USE_POSTGRES=True
DB_NAME=poll_system_db
DB_USER=postgres
DB_PASSWORD=$dbPassword
DB_HOST=db
DB_PORT=5432

# Django Configuration
SECRET_KEY=$secretKey
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1

# Redis Configuration
REDIS_URL=redis://redis:6379/1
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0
"@
        
        $envContent | Out-File -FilePath ".env" -Encoding UTF8
        Write-Status "Created .env file with secure random passwords"
    }
    else {
        Write-Status ".env file already exists"
    }
}

# Deploy PostgreSQL with Docker Compose
function Deploy-PostgreSQL {
    Write-Host "📦 Deploying PostgreSQL with Docker Compose..." -ForegroundColor $White
    
    # Start only the database service first
    docker-compose up -d db redis
    
    # Wait for database to be ready
    Write-Host "⏳ Waiting for PostgreSQL to be ready..." -ForegroundColor $White
    $timeout = 60
    $counter = 0
    
    do {
        Start-Sleep -Seconds 1
        $counter++
        try {
            docker-compose exec db pg_isready -U postgres 2>$null
            if ($LASTEXITCODE -eq 0) {
                break
            }
        }
        catch {
            # Continue waiting
        }
    } while ($counter -lt $timeout)
    
    if ($counter -ge $timeout) {
        Write-Error "PostgreSQL failed to start within $timeout seconds"
        exit 1
    }
    
    Write-Status "PostgreSQL is ready!"
}

# Run database migrations
function Invoke-Migrations {
    Write-Host "🔄 Running database migrations..." -ForegroundColor $White
    
    # Wait a bit more for the database to be fully ready
    Start-Sleep -Seconds 5
    
    # Run migrations
    docker-compose exec web python manage.py migrate
    
    Write-Status "Database migrations completed"
}

# Create superuser (optional)
function New-SuperUser {
    $response = Read-Host "👤 Would you like to create a Django superuser? (y/n)"
    if ($response -match "^[Yy]$") {
        docker-compose exec web python manage.py createsuperuser
        Write-Status "Superuser created"
    }
}

# Show deployment status
function Show-Status {
    Write-Host ""
    Write-Host "📊 Deployment Status:" -ForegroundColor $White
    Write-Host "====================" -ForegroundColor $White
    
    # Show running containers
    docker-compose ps
    
    Write-Host ""
    Write-Host "🔗 Access Information:" -ForegroundColor $White
    Write-Host "=====================" -ForegroundColor $White
    Write-Host "PostgreSQL: localhost:5432" -ForegroundColor $White
    Write-Host "Database: poll_system_db" -ForegroundColor $White
    Write-Host "Username: postgres" -ForegroundColor $White
    Write-Host "Password: (check .env file)" -ForegroundColor $White
    Write-Host ""
    Write-Host "Web Application: http://localhost:8000" -ForegroundColor $White
    Write-Host "API Documentation: http://localhost:8000/api/schema/swagger-ui/" -ForegroundColor $White
    
    Write-Host ""
    Write-Host "📝 Useful Commands:" -ForegroundColor $White
    Write-Host "==================" -ForegroundColor $White
    Write-Host "View logs: docker-compose logs -f" -ForegroundColor $White
    Write-Host "Stop services: docker-compose down" -ForegroundColor $White
    Write-Host "Restart services: docker-compose restart" -ForegroundColor $White
    Write-Host "Connect to database: docker-compose exec db psql -U postgres -d poll_system_db" -ForegroundColor $White
}

# Main deployment function
function Start-Deployment {
    Write-Host "🚀 PostgreSQL Deployment Script" -ForegroundColor $White
    Write-Host "================================" -ForegroundColor $White
    Write-Host ""
    
    if (-not (Test-Docker)) { exit 1 }
    if (-not (Test-DockerCompose)) { exit 1 }
    
    New-EnvFile
    Deploy-PostgreSQL
    Invoke-Migrations
    New-SuperUser
    Show-Status
    
    Write-Host ""
    Write-Status "PostgreSQL deployment completed successfully! 🎉"
}

# Handle script commands
switch ($Command) {
    "deploy" {
        Start-Deployment
    }
    "status" {
        Show-Status
    }
    "logs" {
        docker-compose logs -f
    }
    "stop" {
        docker-compose down
        Write-Status "Services stopped"
    }
    "restart" {
        docker-compose restart
        Write-Status "Services restarted"
    }
    "backup" {
        Write-Host "📦 Creating database backup..." -ForegroundColor $White
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        docker-compose exec db pg_dump -U postgres poll_system_db > "backup_$timestamp.sql"
        Write-Status "Backup created"
    }
    "help" {
        Write-Host "Usage: .\deploy-postgres.ps1 [command]" -ForegroundColor $White
        Write-Host ""
        Write-Host "Commands:" -ForegroundColor $White
        Write-Host "  deploy   - Deploy PostgreSQL (default)" -ForegroundColor $White
        Write-Host "  status   - Show deployment status" -ForegroundColor $White
        Write-Host "  logs     - Show service logs" -ForegroundColor $White
        Write-Host "  stop     - Stop all services" -ForegroundColor $White
        Write-Host "  restart  - Restart all services" -ForegroundColor $White
        Write-Host "  backup   - Create database backup" -ForegroundColor $White
        Write-Host "  help     - Show this help message" -ForegroundColor $White
    }
}
