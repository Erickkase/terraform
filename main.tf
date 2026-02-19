
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region     = var.AWS_REGION
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
  token      = var.AWS_SESSION_TOKEN
}

# ============================================================
# SECURITY GROUPS
# ============================================================

# Security Group para ALB
resource "aws_security_group" "alb_sg" {
  name_prefix = "microservicios-alb-sg"
  vpc_id      = var.vpc_id
  description = "Security group for Application Load Balancer"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "microservicios-alb-sg"
  }
}

# Security Group para Microservicios
resource "aws_security_group" "microservices_sg" {
  name_prefix = "microservicios-ec2-sg"
  vpc_id      = var.vpc_id
  description = "Security group for microservices EC2 instances"

  ingress {
    from_port       = 8081
    to_port         = 8085
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow traffic from ALB on ports 8081-8085"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "microservicios-ec2-sg"
  }
}

# Security Group for PostgreSQL EC2 Instance
resource "aws_security_group" "postgres_sg" {
  name_prefix = "postgres-db-sg"
  vpc_id      = var.vpc_id
  description = "Security group for PostgreSQL EC2 instance"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.microservices_sg.id]
    description     = "PostgreSQL from microservices"
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "PostgreSQL from internet for testing"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "postgres-db-sg"
  }
}

# Security Group for MySQL EC2 Instance
resource "aws_security_group" "mysql_sg" {
  name_prefix = "mysql-db-sg"
  vpc_id      = var.vpc_id
  description = "Security group for MySQL EC2 instance"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.microservices_sg.id]
    description     = "MySQL from microservices"
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "MySQL from internet for testing"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "mysql-db-sg"
  }
}

# ============================================================
# POSTGRESQL DATABASE EC2 INSTANCE
# ============================================================

# Key Pair for PostgreSQL Instance
resource "tls_private_key" "postgres_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "postgres" {
  key_name   = "postgres-db-key"
  public_key = tls_private_key.postgres_key.public_key_openssh
  
  lifecycle {
    ignore_changes = [public_key]
  }
}

# PostgreSQL EC2 Instance (Single instance for database)
resource "aws_instance" "postgres" {
  ami           = var.ami_id
  instance_type = "t2.small"
  key_name      = aws_key_pair.postgres.key_name
  subnet_id     = var.subnet1
  
  vpc_security_group_ids = [aws_security_group.postgres_sg.id]
  
  user_data = base64encode(<<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log)
exec 2>&1
set -x

echo "=========================================="
echo "Starting PostgreSQL instance setup..."
echo "Time: $(date)"
echo "=========================================="

# Update system
echo "[1/6] Updating system..."
apt-get update -y

# Install Docker
echo "[2/6] Installing Docker..."
apt-get install -y docker.io
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to install Docker"
  exit 1
fi

# Start Docker service
echo "[3/6] Starting Docker service..."
systemctl start docker
systemctl enable docker
sleep 5

# Verify Docker is running
if ! docker ps > /dev/null 2>&1; then
  echo "ERROR: Docker is not running properly"
  systemctl status docker
  exit 1
fi

usermod -aG docker ubuntu
docker --version
echo "Docker installed and running successfully!"

# Install Docker Compose
echo "[4/6] Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
/usr/local/bin/docker-compose --version

# Create PostgreSQL directory
echo "[5/6] Creating PostgreSQL configuration..."
mkdir -p /opt/postgres
cd /opt/postgres

# Create init SQL file (using cat without quotes to allow variable expansion)
cat > init-db.sql << SQLEOF
CREATE SCHEMA IF NOT EXISTS service1_schema;
CREATE SCHEMA IF NOT EXISTS service2_schema;
CREATE SCHEMA IF NOT EXISTS service3_schema;

GRANT ALL PRIVILEGES ON SCHEMA service1_schema TO ${var.db_username};
GRANT ALL PRIVILEGES ON SCHEMA service2_schema TO ${var.db_username};
GRANT ALL PRIVILEGES ON SCHEMA service3_schema TO ${var.db_username};

ALTER DATABASE ${var.db_name} SET search_path TO service1_schema, service2_schema, service3_schema, public;
SQLEOF

# Create docker-compose.yml (using cat without quotes to allow variable expansion)
cat > docker-compose.yml << COMPOSEEOF
version: '3.8'

services:
  postgres:
    image: postgres:17.2-alpine
    container_name: postgres-db
    restart: unless-stopped
    network_mode: bridge
    ports:
      - "0.0.0.0:5432:5432"
    environment:
      POSTGRES_DB: ${var.db_name}
      POSTGRES_USER: ${var.db_username}
      POSTGRES_PASSWORD: ${var.db_password}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8"
      POSTGRES_HOST_AUTH_METHOD: "md5"
    command: 
      - postgres
      - -c
      - listen_addresses=*
      - -c
      - max_connections=200
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${var.db_username} -d ${var.db_name}"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
    driver: local
COMPOSEEOF

# Display configuration files for verification
echo "=== init-db.sql ==="
cat init-db.sql
echo "=== docker-compose.yml ==="
cat docker-compose.yml

# Start PostgreSQL
echo "[6/6] Starting PostgreSQL with Docker Compose..."
/usr/local/bin/docker-compose pull
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to pull PostgreSQL image"
  exit 1
fi

/usr/local/bin/docker-compose up -d
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to start PostgreSQL"
  /usr/local/bin/docker-compose logs
  exit 1
fi

# Wait and verify PostgreSQL is fully ready
echo "Waiting for PostgreSQL to be fully ready..."
sleep 30

# Check if container is running
if ! docker ps | grep postgres-db; then
  echo "ERROR: PostgreSQL container is not running!"
  docker ps -a
  /usr/local/bin/docker-compose logs
  exit 1
fi

# Wait for PostgreSQL to accept connections (up to 2 minutes)
echo "Checking PostgreSQL connectivity..."
for i in {1..24}; do
  if docker exec postgres-db pg_isready -U ${var.db_username} -d ${var.db_name} > /dev/null 2>&1; then
    echo "PostgreSQL is ready and accepting connections!"
    break
  fi
  echo "Attempt $i/24: Waiting for PostgreSQL to accept connections..."
  sleep 5
done

echo "=== Docker containers status ==="
docker ps -a
echo "=== Docker Compose status ==="
/usr/local/bin/docker-compose ps
echo "=== PostgreSQL logs (last 20 lines) ==="
/usr/local/bin/docker-compose logs --tail=20

echo "=========================================="
echo "PostgreSQL setup completed successfully!"
echo "Database URL: $(hostname -I | awk '{print $1}'):5432"
echo "Database Name: ${var.db_name}"
echo "Time: $(date)"
echo "=========================================="
EOF
  )
  
  root_block_device {
    volume_type = "gp2"
    volume_size = 20
    encrypted   = false
  }
  
  tags = {
    Name        = "postgres-database"
    Service     = "database"
    Environment = "test"
  }
}

# ============================================================
# MYSQL DATABASE EC2 INSTANCE
# ============================================================

# Key Pair for MySQL Instance
resource "tls_private_key" "mysql_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "mysql" {
  key_name   = "mysql-db-key"
  public_key = tls_private_key.mysql_key.public_key_openssh
  
  lifecycle {
    ignore_changes = [public_key]
  }
}

# MySQL EC2 Instance (Single instance for database)
resource "aws_instance" "mysql" {
  ami           = var.ami_id
  instance_type = "t2.small"
  key_name      = aws_key_pair.mysql.key_name
  subnet_id     = var.subnet1
  
  vpc_security_group_ids = [aws_security_group.mysql_sg.id]
  
  user_data = base64encode(<<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log)
exec 2>&1
set -x

echo "=========================================="
echo "Starting MySQL instance setup..."
echo "Time: $(date)"
echo "=========================================="

# Update system
echo "[1/6] Updating system..."
apt-get update -y

# Install Docker
echo "[2/6] Installing Docker..."
apt-get install -y docker.io
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to install Docker"
  exit 1
fi

# Start Docker service
echo "[3/6] Starting Docker service..."
systemctl start docker
systemctl enable docker
sleep 5

# Verify Docker is running
if ! docker ps > /dev/null 2>&1; then
  echo "ERROR: Docker is not running properly"
  systemctl status docker
  exit 1
fi

usermod -aG docker ubuntu
docker --version
echo "Docker installed and running successfully!"

# Install Docker Compose
echo "[4/6] Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
/usr/local/bin/docker-compose --version

# Create MySQL directory
echo "[5/6] Creating MySQL configuration..."
mkdir -p /opt/mysql
cd /opt/mysql

# Create init SQL file
cat > init-db.sql << SQLEOF
CREATE DATABASE IF NOT EXISTS service4_db;
CREATE DATABASE IF NOT EXISTS service5_db;

GRANT ALL PRIVILEGES ON service4_db.* TO '${var.mysql_username}'@'%';
GRANT ALL PRIVILEGES ON service5_db.* TO '${var.mysql_username}'@'%';

FLUSH PRIVILEGES;
SQLEOF

# Create docker-compose.yml
cat > docker-compose.yml << COMPOSEEOF
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: mysql-db
    restart: unless-stopped
    network_mode: bridge
    ports:
      - "0.0.0.0:3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: ${var.mysql_root_password}
      MYSQL_DATABASE: service4_db
      MYSQL_USER: ${var.mysql_username}
      MYSQL_PASSWORD: ${var.mysql_password}
    command: 
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --bind-address=0.0.0.0
      - --max_connections=200
    volumes:
      - mysql_data:/var/lib/mysql
      - ./init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${var.mysql_root_password}"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  mysql_data:
    driver: local
COMPOSEEOF

# Display configuration files for verification
echo "=== init-db.sql ==="
cat init-db.sql
echo "=== docker-compose.yml ==="
cat docker-compose.yml

# Start MySQL
echo "[6/6] Starting MySQL with Docker Compose..."
/usr/local/bin/docker-compose pull
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to pull MySQL image"
  exit 1
fi

/usr/local/bin/docker-compose up -d
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to start MySQL"
  /usr/local/bin/docker-compose logs
  exit 1
fi

# Wait and verify MySQL is fully ready
echo "Waiting for MySQL to be fully ready..."
sleep 30

# Check if container is running
if ! docker ps | grep mysql-db; then
  echo "ERROR: MySQL container is not running!"
  docker ps -a
  /usr/local/bin/docker-compose logs
  exit 1
fi

# Wait for MySQL to accept connections (up to 2 minutes)
echo "Checking MySQL connectivity..."
for i in {1..24}; do
  if docker exec mysql-db mysqladmin ping -h localhost -u root -p${var.mysql_root_password} > /dev/null 2>&1; then
    echo "MySQL is ready and accepting connections!"
    break
  fi
  echo "Attempt $i/24: Waiting for MySQL to accept connections..."
  sleep 5
done

echo "=== Docker containers status ==="
docker ps -a
echo "=== Docker Compose status ==="
/usr/local/bin/docker-compose ps
echo "=== MySQL logs (last 20 lines) ==="
/usr/local/bin/docker-compose logs --tail=20

echo "=========================================="
echo "MySQL setup completed successfully!"
echo "Database URL: $(hostname -I | awk '{print $1}'):3306"
echo "Time: $(date)"
echo "=========================================="
EOF
  )
  
  root_block_device {
    volume_type = "gp2"
    volume_size = 20
    encrypted   = false
  }
  
  tags = {
    Name        = "mysql-database"
    Service     = "database"
    Environment = "test"
  }
}

# ============================================================
# APPLICATION LOAD BALANCER
# ============================================================

resource "aws_lb" "main_alb" {
  name               = "microservicios-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [var.subnet1, var.subnet2]

  tags = {
    Name = "microservicios-alb"
  }
}

# ALB Listener HTTP
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Service not found"
      status_code  = "404"
    }
  }
}

# ============================================================
# TARGET GROUPS
# ============================================================

# Target Group - service1 (port 8081)
resource "aws_lb_target_group" "service1_tg" {
  name_prefix = "svc1-"
  port     = 8081
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  lifecycle {
    create_before_destroy = true
  }
  
  health_check {
    enabled             = true
    path                = "/actuator/health"
    port                = "8081"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "service1-target-group"
  }
}

# Target Group - service2 (port 8082)
resource "aws_lb_target_group" "service2_tg" {
  name_prefix = "svc2-"
  port     = 8082
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  lifecycle {
    create_before_destroy = true
  }
  
  health_check {
    enabled             = true
    path                = "/actuator/health"
    port                = "8082"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "service2-target-group"
  }
}

# Target Group - service3 (port 8083)
resource "aws_lb_target_group" "service3_tg" {
  name_prefix = "svc3-"
  port     = 8083
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  lifecycle {
    create_before_destroy = true
  }
  
  health_check {
    enabled             = true
    path                = "/actuator/health"
    port                = "8083"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "service3-target-group"
  }
}

# Target Group - service4 (port 8084)
resource "aws_lb_target_group" "service4_tg" {
  name_prefix = "svc4-"
  port     = 8084
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  lifecycle {
    create_before_destroy = true
  }
  
  health_check {
    enabled             = true
    path                = "/actuator/health"
    port                = "8084"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "service4-target-group"
  }
}

# Target Group - service5 (port 8085)
resource "aws_lb_target_group" "service5_tg" {
  name_prefix = "svc5-"
  port     = 8085
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  lifecycle {
    create_before_destroy = true
  }
  
  health_check {
    enabled             = true
    path                = "/actuator/health"
    port                = "8085"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "service5-target-group"
  }
}

# ============================================================
# ALB LISTENER RULES
# ============================================================

# Rule for service1: /api/service1/*
resource "aws_lb_listener_rule" "service1_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service1_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/service1*"]
    }
  }
}

# Rule for service2: /api/service2/*
resource "aws_lb_listener_rule" "service2_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 110

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service2_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/service2*"]
    }
  }
}

# Rule for service3: /api/service3/*
resource "aws_lb_listener_rule" "service3_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 120

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service3_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/service3*"]
    }
  }
}

# Rule for service4: /api/service4/*
resource "aws_lb_listener_rule" "service4_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 130

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service4_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/service4*"]
    }
  }
}

# Rule for service5: /api/service5/*
resource "aws_lb_listener_rule" "service5_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 140

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service5_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/service5*"]
    }
  }
}

# ============================================================
# SSH KEY PAIRS
# ============================================================

resource "tls_private_key" "service1_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "service1" {
  key_name   = "service1-key"
  public_key = tls_private_key.service1_key.public_key_openssh
  
  lifecycle {
    ignore_changes = [public_key]
  }
}

resource "tls_private_key" "service2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "service2" {
  key_name   = "service2-key"
  public_key = tls_private_key.service2_key.public_key_openssh
  
  lifecycle {
    ignore_changes = [public_key]
  }
}

resource "tls_private_key" "service3_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "service3" {
  key_name   = "service3-key"
  public_key = tls_private_key.service3_key.public_key_openssh
  
  lifecycle {
    ignore_changes = [public_key]
  }
}

resource "tls_private_key" "service4_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "service4" {
  key_name   = "service4-key"
  public_key = tls_private_key.service4_key.public_key_openssh
  
  lifecycle {
    ignore_changes = [public_key]
  }
}

resource "tls_private_key" "service5_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "service5" {
  key_name   = "service5-key"
  public_key = tls_private_key.service5_key.public_key_openssh
  
  lifecycle {
    ignore_changes = [public_key]
  }
}

# ============================================================
# LAUNCH TEMPLATES
# ============================================================

# Launch Template - service1
resource "aws_launch_template" "service1_lt" {
  name_prefix   = "service1-lt-"
  image_id      = var.ami_id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.service1.key_name

  vpc_security_group_ids = [aws_security_group.microservices_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    set -x
    
    echo "Starting service1 setup at $(date)"
    
    # Install Docker
    apt-get update -y
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    sleep 5
    usermod -aG docker ubuntu
    
    # Pull service1 container
    docker pull ${var.docker_hub_username}/service1:${var.image_tag}
    
    # Wait for PostgreSQL to be ready
    echo "Waiting for PostgreSQL at ${aws_instance.postgres.private_ip}:5432..."
    for i in {1..30}; do
      if timeout 2 bash -c "</dev/tcp/${aws_instance.postgres.private_ip}/5432" 2>/dev/null; then
        echo "PostgreSQL is accepting connections!"
        break
      fi
      echo "Attempt $i/30: PostgreSQL not ready yet..."
      sleep 10
    done
    
    # Run service1 container
    docker run -d \
      --name service1 \
      --restart unless-stopped \
      -p 8081:8081 \
      -e SERVER_PORT=8081 \
      -e DATABASE_URL="jdbc:postgresql://${aws_instance.postgres.private_ip}:5432/${var.db_name}?currentSchema=service1_schema" \
      -e DATABASE_USERNAME="${var.db_username}" \
      -e DATABASE_PASSWORD="${var.db_password}" \
      -e JPA_DDL_AUTO=update \
      -e JPA_SHOW_SQL=false \
      -e LOG_LEVEL=INFO \
      ${var.docker_hub_username}/service1:${var.image_tag}
    
    echo "service1 started at $(date)"
    docker ps
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "service1-instance"
      Service = "service1"
    }
  }
}

# Launch Template - service2
resource "aws_launch_template" "service2_lt" {
  name_prefix   = "service2-lt-"
  image_id      = var.ami_id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.service2.key_name

  vpc_security_group_ids = [aws_security_group.microservices_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    set -x
    
    echo "Starting service2 setup at $(date)"
    
    # Install Docker
    apt-get update -y
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    sleep 5
    usermod -aG docker ubuntu
    
    # Pull service2 container
    docker pull ${var.docker_hub_username}/service2:${var.image_tag}
    
    # Wait for PostgreSQL to be ready
    echo "Waiting for PostgreSQL at ${aws_instance.postgres.private_ip}:5432..."
    for i in {1..30}; do
      if timeout 2 bash -c "</dev/tcp/${aws_instance.postgres.private_ip}/5432" 2>/dev/null; then
        echo "PostgreSQL is accepting connections!"
        break
      fi
      echo "Attempt $i/30: PostgreSQL not ready yet..."
      sleep 10
    done
    
    # Run service2 container
    docker run -d \
      --name service2 \
      --restart unless-stopped \
      -p 8082:8082 \
      -e SERVER_PORT=8082 \
      -e DATABASE_URL="jdbc:postgresql://${aws_instance.postgres.private_ip}:5432/${var.db_name}?currentSchema=service2_schema" \
      -e DATABASE_USERNAME="${var.db_username}" \
      -e DATABASE_PASSWORD="${var.db_password}" \
      -e JPA_DDL_AUTO=update \
      -e JPA_SHOW_SQL=false \
      -e LOG_LEVEL=INFO \
      ${var.docker_hub_username}/service2:${var.image_tag}
    
    echo "service2 started at $(date)"
    docker ps
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "service2-instance"
      Service = "service2"
    }
  }
}

# Launch Template - service3
resource "aws_launch_template" "service3_lt" {
  name_prefix   = "service3-lt-"
  image_id      = var.ami_id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.service3.key_name

  vpc_security_group_ids = [aws_security_group.microservices_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    set -x
    
    echo "Starting service3 setup at $(date)"
    
    # Install Docker
    apt-get update -y
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    sleep 5
    usermod -aG docker ubuntu
    
    # Pull service3 container
    docker pull ${var.docker_hub_username}/service3:${var.image_tag}
    
    # Wait for PostgreSQL to be ready
    echo "Waiting for PostgreSQL at ${aws_instance.postgres.private_ip}:5432..."
    for i in {1..30}; do
      if timeout 2 bash -c "</dev/tcp/${aws_instance.postgres.private_ip}/5432" 2>/dev/null; then
        echo "PostgreSQL is accepting connections!"
        break
      fi
      echo "Attempt $i/30: PostgreSQL not ready yet..."
      sleep 10
    done
    
    # Run service3 container
    docker run -d \
      --name service3 \
      --restart unless-stopped \
      -p 8083:8083 \
      -e SERVER_PORT=8083 \
      -e DATABASE_URL="jdbc:postgresql://${aws_instance.postgres.private_ip}:5432/${var.db_name}?currentSchema=service3_schema" \
      -e DATABASE_USERNAME="${var.db_username}" \
      -e DATABASE_PASSWORD="${var.db_password}" \
      -e JPA_DDL_AUTO=update \
      -e JPA_SHOW_SQL=false \
      -e LOG_LEVEL=INFO \
      ${var.docker_hub_username}/service3:${var.image_tag}
    
    echo "service3 started at $(date)"
    docker ps
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "service3-instance"
      Service = "service3"
    }
  }
}

# Launch Template - service4
resource "aws_launch_template" "service4_lt" {
  name_prefix   = "service4-lt-"
  image_id      = var.ami_id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.service4.key_name

  vpc_security_group_ids = [aws_security_group.microservices_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    set -x
    
    echo "Starting service4 setup at $(date)"
    
    # Install Docker
    apt-get update -y
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    sleep 5
    usermod -aG docker ubuntu
    
    # Pull service4 container
    docker pull ${var.docker_hub_username}/service4:${var.image_tag}
    
    # Wait for MySQL to be ready
    echo "Waiting for MySQL at ${aws_instance.mysql.private_ip}:3306..."
    for i in {1..30}; do
      if timeout 2 bash -c "</dev/tcp/${aws_instance.mysql.private_ip}/3306" 2>/dev/null; then
        echo "MySQL is accepting connections!"
        break
      fi
      echo "Attempt $i/30: MySQL not ready yet..."
      sleep 10
    done
    
    # Run service4 container
    docker run -d \
      --name service4 \
      --restart unless-stopped \
      -p 8084:8084 \
      -e SERVER_PORT=8084 \
      -e DATABASE_URL="jdbc:mysql://${aws_instance.mysql.private_ip}:3306/service4_db?useSSL=false&allowPublicKeyRetrieval=true" \
      -e DATABASE_USERNAME="${var.mysql_username}" \
      -e DATABASE_PASSWORD="${var.mysql_password}" \
      -e JPA_DDL_AUTO=update \
      -e JPA_SHOW_SQL=false \
      -e LOG_LEVEL=INFO \
      ${var.docker_hub_username}/service4:${var.image_tag}
    
    echo "service4 started at $(date)"
    docker ps
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "service4-instance"
      Service = "service4"
    }
  }
}

# Launch Template - service5
resource "aws_launch_template" "service5_lt" {
  name_prefix   = "service5-lt-"
  image_id      = var.ami_id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.service5.key_name

  vpc_security_group_ids = [aws_security_group.microservices_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    set -x
    
    echo "Starting service5 setup at $(date)"
    
    # Install Docker
    apt-get update -y
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    sleep 5
    usermod -aG docker ubuntu
    
    # Pull service5 container
    docker pull ${var.docker_hub_username}/service5:${var.image_tag}
    
    # Wait for MySQL to be ready
    echo "Waiting for MySQL at ${aws_instance.mysql.private_ip}:3306..."
    for i in {1..30}; do
      if timeout 2 bash -c "</dev/tcp/${aws_instance.mysql.private_ip}/3306" 2>/dev/null; then
        echo "MySQL is accepting connections!"
        break
      fi
      echo "Attempt $i/30: MySQL not ready yet..."
      sleep 10
    done
    
    # Run service5 container
    docker run -d \
      --name service5 \
      --restart unless-stopped \
      -p 8085:8085 \
      -e SERVER_PORT=8085 \
      -e DATABASE_URL="jdbc:mysql://${aws_instance.mysql.private_ip}:3306/service5_db?useSSL=false&allowPublicKeyRetrieval=true" \
      -e DATABASE_USERNAME="${var.mysql_username}" \
      -e DATABASE_PASSWORD="${var.mysql_password}" \
      -e JPA_DDL_AUTO=update \
      -e JPA_SHOW_SQL=false \
      -e LOG_LEVEL=INFO \
      ${var.docker_hub_username}/service5:${var.image_tag}
    
    echo "service5 started at $(date)"
    docker ps
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "service5-instance"
      Service = "service5"
    }
  }
}

# ============================================================
# AUTO SCALING GROUPS
# ============================================================

# ASG - service1 (min: 1, max: 1, desired: 1)
resource "aws_autoscaling_group" "service1_asg" {
  name                = "service1-asg"
  vpc_zone_identifier = [var.subnet1, var.subnet2]
  target_group_arns   = [aws_lb_target_group.service1_tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.service1_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "service1-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Service"
    value               = "service1"
    propagate_at_launch = true
  }
}

# ASG - service2 (min: 1, max: 1, desired: 1)
resource "aws_autoscaling_group" "service2_asg" {
  name                = "service2-asg"
  vpc_zone_identifier = [var.subnet1, var.subnet2]
  target_group_arns   = [aws_lb_target_group.service2_tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.service2_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "service2-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Service"
    value               = "service2"
    propagate_at_launch = true
  }
}

# ASG - service3 (min: 1, max: 1, desired: 1)
resource "aws_autoscaling_group" "service3_asg" {
  name                = "service3-asg"
  vpc_zone_identifier = [var.subnet1, var.subnet2]
  target_group_arns   = [aws_lb_target_group.service3_tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.service3_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "service3-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Service"
    value               = "service3"
    propagate_at_launch = true
  }
}

# ASG - service4 (min: 1, max: 1, desired: 1)
resource "aws_autoscaling_group" "service4_asg" {
  name                = "service4-asg"
  vpc_zone_identifier = [var.subnet1, var.subnet2]
  target_group_arns   = [aws_lb_target_group.service4_tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.service4_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "service4-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Service"
    value               = "service4"
    propagate_at_launch = true
  }
}

# ASG - service5 (min: 1, max: 1, desired: 1)
resource "aws_autoscaling_group" "service5_asg" {
  name                = "service5-asg"
  vpc_zone_identifier = [var.subnet1, var.subnet2]
  target_group_arns   = [aws_lb_target_group.service5_tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.service5_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "service5-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Service"
    value               = "service5"
    propagate_at_launch = true
  }
}

# ============================================================
# AUTO SCALING POLICIES (CPU-based)
# ============================================================

# Scale UP policy - service1
resource "aws_autoscaling_policy" "service1_scale_up" {
  name                   = "service1-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.service1_asg.name
}

resource "aws_cloudwatch_metric_alarm" "service1_cpu_high" {
  alarm_name          = "service1-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.service1_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.service1_scale_up.arn]
}

# Scale DOWN policy - service1
resource "aws_autoscaling_policy" "service1_scale_down" {
  name                   = "service1-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.service1_asg.name
}

resource "aws_cloudwatch_metric_alarm" "service1_cpu_low" {
  alarm_name          = "service1-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.service1_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.service1_scale_down.arn]
}

# Scale UP policy - service2
resource "aws_autoscaling_policy" "service2_scale_up" {
  name                   = "service2-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.service2_asg.name
}

resource "aws_cloudwatch_metric_alarm" "service2_cpu_high" {
  alarm_name          = "service2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.service2_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.service2_scale_up.arn]
}

# Scale DOWN policy - service2
resource "aws_autoscaling_policy" "service2_scale_down" {
  name                   = "service2-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.service2_asg.name
}

resource "aws_cloudwatch_metric_alarm" "service2_cpu_low" {
  alarm_name          = "service2-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.service2_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.service2_scale_down.arn]
}

# Scale UP policy - service3
resource "aws_autoscaling_policy" "service3_scale_up" {
  name                   = "service3-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.service3_asg.name
}

resource "aws_cloudwatch_metric_alarm" "service3_cpu_high" {
  alarm_name          = "service3-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.service3_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.service3_scale_up.arn]
}

# Scale DOWN policy - service3
resource "aws_autoscaling_policy" "service3_scale_down" {
  name                   = "service3-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.service3_asg.name
}

resource "aws_cloudwatch_metric_alarm" "service3_cpu_low" {
  alarm_name          = "service3-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.service3_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.service3_scale_down.arn]
}

# Scale UP policy - service4
resource "aws_autoscaling_policy" "service4_scale_up" {
  name                   = "service4-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.service4_asg.name
}

resource "aws_cloudwatch_metric_alarm" "service4_cpu_high" {
  alarm_name          = "service4-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.service4_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.service4_scale_up.arn]
}

# Scale DOWN policy - service4
resource "aws_autoscaling_policy" "service4_scale_down" {
  name                   = "service4-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.service4_asg.name
}

resource "aws_cloudwatch_metric_alarm" "service4_cpu_low" {
  alarm_name          = "service4-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.service4_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.service4_scale_down.arn]
}

# Scale UP policy - service5
resource "aws_autoscaling_policy" "service5_scale_up" {
  name                   = "service5-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.service5_asg.name
}

resource "aws_cloudwatch_metric_alarm" "service5_cpu_high" {
  alarm_name          = "service5-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.service5_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.service5_scale_up.arn]
}

# Scale DOWN policy - service5
resource "aws_autoscaling_policy" "service5_scale_down" {
  name                   = "service5-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.service5_asg.name
}

resource "aws_cloudwatch_metric_alarm" "service5_cpu_low" {
  alarm_name          = "service5-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.service5_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.service5_scale_down.arn]
}

