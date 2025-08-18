# Terraform Backend Configuration for Remote State Management
# This file configures the S3 backend for storing Terraform state

# Note: The actual backend configuration is environment-specific
# and should be initialized with terraform init -backend-config=<environment>.backend

# Example backend configurations for each environment:

# Development Backend Configuration
# Create file: environments/dev.backend
# bucket         = "your-terraform-state-bucket"
# key            = "streamlit-ecs/dev/terraform.tfstate"  
# region         = "us-east-1"
# dynamodb_table = "terraform-state-locks"
# encrypt        = true

# Staging Backend Configuration  
# Create file: environments/staging.backend
# bucket         = "your-terraform-state-bucket"
# key            = "streamlit-ecs/staging/terraform.tfstate"
# region         = "us-east-1"
# dynamodb_table = "terraform-state-locks"
# encrypt        = true

# Production Backend Configuration
# Create file: environments/prod.backend
# bucket         = "your-terraform-state-bucket" 
# key            = "streamlit-ecs/prod/terraform.tfstate"
# region         = "us-east-1"
# dynamodb_table = "terraform-state-locks"
# encrypt        = true

# Usage Instructions:
# 1. Create the S3 bucket and DynamoDB table for state management
# 2. Create environment-specific .backend files in environments/ directory
# 3. Initialize Terraform with: terraform init -backend-config=environments/dev.backend
# 4. Plan with: terraform plan -var-file=environments/dev.tfvars
# 5. Apply with: terraform apply -var-file=environments/dev.tfvars

# If using local state (not recommended for production), comment out the backend block in main.tf