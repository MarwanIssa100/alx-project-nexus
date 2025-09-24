#!/bin/bash

# PostgreSQL Deployment Script
# This script helps deploy PostgreSQL for the poll system

set -e

echo "🚀 PostgreSQL Deployment Script"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    print_status "Docker is installed"
}

# Check if Docker Compose is installed
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    print_status "Docker Compose is installed"
}

# Create .env file if it doesn't exist
create_env_file() {
    if [ ! -f .env ]; then
        print_warning ".env file not found. Creating from template..."
        cat > .env << EOF
# Database Configuration
USE_POSTGRES=True
DB_NAME=poll_system_db
DB_USER=postgres
DB_PASSWORD=$(openssl rand -base64 32)
DB_HOST=db
DB_PORT=5432

# Django Configuration
SECRET_KEY=$(openssl rand -base64 50)
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1

# Redis Configuration
REDIS_URL=redis://redis:6379/1
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0
EOF
        print_status "Created .env file with secure random passwords"
    else
        print_status ".env file already exists"
    fi
}

# Deploy PostgreSQL with Docker Compose
deploy_postgres() {
    echo "📦 Deploying PostgreSQL with Docker Compose..."
    
    # Start only the database service first
    docker-compose up -d db redis
    
    # Wait for database to be ready
    echo "⏳ Waiting for PostgreSQL to be ready..."
    timeout=60
    counter=0
    
    while ! docker-compose exec db pg_isready -U postgres &> /dev/null; do
        if [ $counter -eq $timeout ]; then
            print_error "PostgreSQL failed to start within $timeout seconds"
            exit 1
        fi
        sleep 1
        counter=$((counter + 1))
    done
    
    print_status "PostgreSQL is ready!"
}

# Run database migrations
run_migrations() {
    echo "🔄 Running database migrations..."
    
    # Wait a bit more for the database to be fully ready
    sleep 5
    
    # Run migrations
    docker-compose exec web python manage.py migrate
    
    print_status "Database migrations completed"
}

# Create superuser (optional)
create_superuser() {
    echo "👤 Would you like to create a Django superuser? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        docker-compose exec web python manage.py createsuperuser
        print_status "Superuser created"
    fi
}

# Show deployment status
show_status() {
    echo ""
    echo "📊 Deployment Status:"
    echo "===================="
    
    # Show running containers
    docker-compose ps
    
    echo ""
    echo "🔗 Access Information:"
    echo "====================="
    echo "PostgreSQL: localhost:5432"
    echo "Database: poll_system_db"
    echo "Username: postgres"
    echo "Password: (check .env file)"
    echo ""
    echo "Web Application: http://localhost:8000"
    echo "API Documentation: http://localhost:8000/api/schema/swagger-ui/"
    
    echo ""
    echo "📝 Useful Commands:"
    echo "=================="
    echo "View logs: docker-compose logs -f"
    echo "Stop services: docker-compose down"
    echo "Restart services: docker-compose restart"
    echo "Connect to database: docker-compose exec db psql -U postgres -d poll_system_db"
}

# Main deployment function
main() {
    echo "Starting PostgreSQL deployment..."
    echo ""
    
    check_docker
    check_docker_compose
    create_env_file
    deploy_postgres
    run_migrations
    create_superuser
    show_status
    
    echo ""
    print_status "PostgreSQL deployment completed successfully! 🎉"
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "status")
        show_status
        ;;
    "logs")
        docker-compose logs -f
        ;;
    "stop")
        docker-compose down
        print_status "Services stopped"
        ;;
    "restart")
        docker-compose restart
        print_status "Services restarted"
        ;;
    "backup")
        echo "📦 Creating database backup..."
        docker-compose exec db pg_dump -U postgres poll_system_db > backup_$(date +%Y%m%d_%H%M%S).sql
        print_status "Backup created"
        ;;
    "help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  deploy   - Deploy PostgreSQL (default)"
        echo "  status   - Show deployment status"
        echo "  logs     - Show service logs"
        echo "  stop     - Stop all services"
        echo "  restart  - Restart all services"
        echo "  backup   - Create database backup"
        echo "  help     - Show this help message"
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use '$0 help' for available commands"
        exit 1
        ;;
esac
