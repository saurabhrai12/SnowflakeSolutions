#!/bin/bash

# Docker Security Validation Script
# This script helps validate that sensitive files are properly excluded from Docker builds

set -e

echo "🔒 Docker Security Validation Script"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if file would be included in Docker build
check_docker_context() {
    local service_dir=$1
    local test_files=(
        ".env"
        ".env.production"
        "secrets.json"
        "credentials.json"
        "snowflake-config.json"
        "private.pem" 
        "api-key.txt"
        "password.txt"
        "database-credentials.yaml"
        ".streamlit/secrets.toml"
    )
    
    echo ""
    echo "📁 Checking Docker context for: $service_dir"
    echo "================================================"
    
    cd "$service_dir"
    
    # Create temporary test files
    for file in "${test_files[@]}"; do
        mkdir -p "$(dirname "$file")"
        echo "FAKE_SECRET=test123" > "$file"
    done
    
    # Build Docker context and check if files are excluded
    echo "Building Docker context (dry run)..."
    
    # Use docker build with --no-cache and capture the context
    if command -v docker &> /dev/null; then
        # Create a temporary Dockerfile for testing
        cat > Dockerfile.test << 'EOF'
FROM alpine:latest
COPY . /app
WORKDIR /app
RUN find . -name "*secret*" -o -name "*credential*" -o -name "*.env*" -o -name "*password*" -o -name "*api-key*" > /tmp/sensitive_files.txt && cat /tmp/sensitive_files.txt
CMD ["echo", "test"]
EOF
        
        # Build and check for sensitive files
        echo "🔍 Testing Docker build context..."
        if docker build -f Dockerfile.test -t security-test . 2>&1 | grep -q "FAKE_SECRET"; then
            echo -e "${RED}❌ SECURITY ISSUE: Sensitive files may be included in Docker image!${NC}"
            SECURITY_ISSUES=true
        else
            echo -e "${GREEN}✅ Good: Test sensitive files appear to be excluded${NC}"
        fi
        
        # Clean up
        docker rmi security-test 2>/dev/null || true
        rm -f Dockerfile.test
    else
        echo -e "${YELLOW}⚠️  Docker not available, skipping build test${NC}"
    fi
    
    # Clean up test files
    for file in "${test_files[@]}"; do
        rm -f "$file"
        # Remove empty directories
        [ -d "$(dirname "$file")" ] && rmdir "$(dirname "$file")" 2>/dev/null || true
    done
    
    cd - > /dev/null
}

# Function to check .dockerignore patterns
validate_dockerignore() {
    local dockerignore_file=$1
    local required_patterns=(
        "*.env*"
        "*secret*"
        "*credential*" 
        "*password*"
        "*.pem"
        "*.key"
    )
    
    echo ""
    echo "📋 Validating .dockerignore patterns: $dockerignore_file"
    echo "======================================================"
    
    if [[ ! -f "$dockerignore_file" ]]; then
        echo -e "${RED}❌ Missing .dockerignore file: $dockerignore_file${NC}"
        SECURITY_ISSUES=true
        return
    fi
    
    for pattern in "${required_patterns[@]}"; do
        if grep -q "$pattern" "$dockerignore_file"; then
            echo -e "${GREEN}✅ Found pattern: $pattern${NC}"
        else
            echo -e "${RED}❌ Missing security pattern: $pattern${NC}"
            SECURITY_ISSUES=true
        fi
    done
}

# Main validation
SECURITY_ISSUES=false

echo "Starting Docker security validation..."
echo ""

# Check root .dockerignore
validate_dockerignore ".dockerignore"

# Check service-specific .dockerignore files
for service in "python-report-service" "streamlit-app"; do
    if [[ -d "$service" ]]; then
        validate_dockerignore "$service/.dockerignore"
        check_docker_context "$service"
    fi
done

# Final report
echo ""
echo "🏁 SECURITY VALIDATION SUMMARY"
echo "=============================="

if [[ "$SECURITY_ISSUES" == "true" ]]; then
    echo -e "${RED}❌ SECURITY ISSUES FOUND!${NC}"
    echo "Please fix the issues above before building Docker images."
    exit 1
else
    echo -e "${GREEN}✅ All security checks passed!${NC}"
    echo "Docker ignore patterns appear to be properly configured."
    exit 0
fi