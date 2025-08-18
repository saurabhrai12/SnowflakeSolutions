#!/bin/bash

# Terraform Validation and Linting Script
# This script performs comprehensive validation of Terraform configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Default values
ENVIRONMENT="dev"
FIX_FORMAT=false
DETAILED_PLAN=false

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -e, --environment    Environment to validate (dev|staging|prod) [default: dev]"
    echo "  -f, --fix-format     Automatically fix formatting issues"
    echo "  -d, --detailed-plan  Show detailed terraform plan output"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   # Validate dev environment"
    echo "  $0 -e prod           # Validate prod environment"
    echo "  $0 -f                # Validate and fix formatting"
    echo "  $0 -d -e staging     # Validate staging with detailed plan"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -f|--fix-format)
            FIX_FORMAT=true
            shift
            ;;
        -d|--detailed-plan)
            DETAILED_PLAN=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_message $RED "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

print_message $BLUE "🔍 Starting Terraform Validation"
print_message $BLUE "================================"
echo "Environment: $ENVIRONMENT"
echo "Fix Format: $FIX_FORMAT"
echo "Detailed Plan: $DETAILED_PLAN"
echo ""

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_message $RED "❌ Terraform is not installed"
    exit 1
fi

print_message $GREEN "✅ Terraform is installed ($(terraform version | head -n1))"

# Check if environment files exist
TFVARS_FILE="environments/${ENVIRONMENT}.tfvars"
BACKEND_CONFIG="environments/${ENVIRONMENT}.backend"

if [[ ! -f "$TFVARS_FILE" ]]; then
    print_message $RED "❌ Environment file $TFVARS_FILE not found"
    exit 1
fi

if [[ ! -f "$BACKEND_CONFIG" ]]; then
    print_message $RED "❌ Backend config file $BACKEND_CONFIG not found"
    exit 1
fi

print_message $GREEN "✅ Environment configuration files found"

# Step 1: Format check/fix
print_message $BLUE "📝 Checking Terraform formatting..."
if [[ "$FIX_FORMAT" == "true" ]]; then
    print_message $YELLOW "🔧 Fixing formatting issues..."
    terraform fmt -recursive .
    print_message $GREEN "✅ Formatting fixed"
else
    if terraform fmt -check -diff -recursive .; then
        print_message $GREEN "✅ Formatting is correct"
    else
        print_message $YELLOW "⚠️  Formatting issues found. Run with -f to fix them."
    fi
fi

# Step 2: Initialize Terraform (if needed)
if [[ ! -d ".terraform" ]]; then
    print_message $BLUE "🔧 Initializing Terraform..."
    terraform init -backend-config="$BACKEND_CONFIG" -upgrade
else
    print_message $GREEN "✅ Terraform already initialized"
fi

# Step 3: Validate configuration
print_message $BLUE "🔍 Validating Terraform configuration..."
if terraform validate; then
    print_message $GREEN "✅ Terraform configuration is valid"
else
    print_message $RED "❌ Terraform configuration validation failed"
    exit 1
fi

# Step 4: Security and best practices check (if tflint is available)
if command -v tflint &> /dev/null; then
    print_message $BLUE "🔒 Running TFLint security checks..."
    if tflint --init 2>/dev/null || true; then
        if tflint; then
            print_message $GREEN "✅ TFLint checks passed"
        else
            print_message $YELLOW "⚠️  TFLint found some issues"
        fi
    fi
else
    print_message $YELLOW "⚠️  TFLint not installed - skipping security checks"
    print_message $YELLOW "    Install with: curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash"
fi

# Step 5: Cost estimation (if infracost is available)
if command -v infracost &> /dev/null; then
    print_message $BLUE "💰 Running cost estimation..."
    if infracost breakdown --path . --terraform-var-file="$TFVARS_FILE" --format table; then
        print_message $GREEN "✅ Cost estimation completed"
    else
        print_message $YELLOW "⚠️  Cost estimation failed"
    fi
else
    print_message $YELLOW "⚠️  Infracost not installed - skipping cost estimation"
    print_message $YELLOW "    Install from: https://www.infracost.io/docs/#quick-start"
fi

# Step 6: Plan validation (dry-run)
print_message $BLUE "📋 Running Terraform plan validation..."
if [[ "$DETAILED_PLAN" == "true" ]]; then
    terraform plan -var-file="$TFVARS_FILE" -detailed-exitcode
    PLAN_EXIT_CODE=$?
else
    terraform plan -var-file="$TFVARS_FILE" -detailed-exitcode > /dev/null 2>&1
    PLAN_EXIT_CODE=$?
fi

case $PLAN_EXIT_CODE in
    0)
        print_message $GREEN "✅ No changes needed - infrastructure is up to date"
        ;;
    1)
        print_message $RED "❌ Terraform plan failed"
        exit 1
        ;;
    2)
        print_message $YELLOW "⚡ Changes detected - infrastructure will be modified"
        if [[ "$DETAILED_PLAN" != "true" ]]; then
            print_message $YELLOW "    Run with -d to see detailed changes"
        fi
        ;;
esac

# Step 7: Check for Terraform state consistency (if backend is configured)
print_message $BLUE "🔄 Checking state consistency..."
if terraform state list > /dev/null 2>&1; then
    STATE_RESOURCES=$(terraform state list | wc -l)
    print_message $GREEN "✅ Terraform state is accessible ($STATE_RESOURCES resources tracked)"
else
    print_message $YELLOW "⚠️  Terraform state is not accessible (fresh deployment?)"
fi

# Step 8: Validate AWS credentials and permissions
print_message $BLUE "🔑 Validating AWS credentials..."
if aws sts get-caller-identity > /dev/null 2>&1; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    print_message $GREEN "✅ AWS credentials valid"
    print_message $GREEN "    Account: $AWS_ACCOUNT_ID"
    print_message $GREEN "    User: $AWS_USER_ARN"
else
    print_message $RED "❌ AWS credentials not configured or invalid"
    exit 1
fi

# Summary
print_message $BLUE ""
print_message $BLUE "📊 Validation Summary"
print_message $BLUE "===================="
print_message $GREEN "✅ All validation checks completed"
print_message $GREEN "✅ Configuration is ready for deployment"

if [[ $PLAN_EXIT_CODE -eq 2 ]]; then
    print_message $YELLOW ""
    print_message $YELLOW "🚀 Next Steps:"
    print_message $YELLOW "   Run: ./deploy.sh -e $ENVIRONMENT --plan-only    # Review changes"
    print_message $YELLOW "   Run: ./deploy.sh -e $ENVIRONMENT                # Apply changes"
elif [[ $PLAN_EXIT_CODE -eq 0 ]]; then
    print_message $GREEN ""
    print_message $GREEN "🎯 Infrastructure is up to date!"
    print_message $GREEN "   No deployment needed for $ENVIRONMENT environment"
fi