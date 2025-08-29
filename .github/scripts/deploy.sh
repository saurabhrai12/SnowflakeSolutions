#!/bin/bash

# Configuration-driven Snowflake deployment script
# Usage: ./deploy.sh <environment> <mode> [target_schemas]

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../deployment-config.yml"
TEMP_DIR="temp-sql"

# Input parameters
ENVIRONMENT="${1:-DEV}"
DEPLOYMENT_MODE="${2:-INCREMENTAL}"
TARGET_SCHEMAS="${3:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN:${NC} $1"
}

# Parse YAML configuration (simplified - requires yq in production)
parse_config() {
    if ! command -v yq &> /dev/null; then
        error "yq is required to parse YAML configuration. Install with: brew install yq"
        exit 1
    fi
    
    # Extract environment configuration
    DATABASE=$(yq eval ".environments.$ENVIRONMENT.database" "$CONFIG_FILE")
    WAREHOUSE=$(yq eval ".environments.$ENVIRONMENT.warehouse" "$CONFIG_FILE")
    
    if [ "$DATABASE" == "null" ] || [ "$WAREHOUSE" == "null" ]; then
        error "Environment '$ENVIRONMENT' not found in configuration"
        exit 1
    fi
    
    log "Environment: $ENVIRONMENT"
    log "Database: $DATABASE"
    log "Warehouse: $WAREHOUSE"
}

# Process SQL file with environment-specific replacements
process_sql_file() {
    local original_file="$1"
    local temp_file="$TEMP_DIR/$(basename "$original_file")"
    
    log "🔧 Processing: $original_file"
    mkdir -p "$TEMP_DIR"
    cp "$original_file" "$temp_file"
    
    # Apply replacements from configuration
    sed -i "s/USE DATABASE analytics_platform;/USE DATABASE $DATABASE;/g" "$temp_file"
    sed -i "s/CREATE OR ALTER DATABASE analytics_platform;/CREATE OR ALTER DATABASE $DATABASE;/g" "$temp_file"
    
    echo "$temp_file"
}

# Execute SQL file
execute_sql_file() {
    local sql_file="$1"
    local description="${2:-}"
    
    if [ ! -f "$sql_file" ]; then
        warn "File not found: $sql_file"
        return 1
    fi
    
    log "📊 Executing: $sql_file ${description:+($description)}"
    
    # Process file for environment-specific changes
    processed_file=$(process_sql_file "$sql_file")
    
    # Execute with Snowflake CLI
    if ! snow sql -f "$processed_file" --connection default; then
        error "Failed to execute: $sql_file"
        return 1
    fi
    
    return 0
}

# Deploy files in a schema directory with proper ordering
deploy_schema_files() {
    local schema_path="$1"
    local schema_name="$2"
    
    if [ ! -d "$schema_path" ]; then
        warn "Schema directory not found: $schema_path"
        return 0
    fi
    
    log "📂 Deploying schema: $schema_name ($schema_path)"
    
    local files_deployed=0
    
    # Get object types from configuration and sort by priority
    while IFS= read -r object_type; do
        local pattern=$(yq eval ".object_types[] | select(.name == \"$object_type\") | .pattern" "$CONFIG_FILE")
        local description=$(yq eval ".object_types[] | select(.name == \"$object_type\") | .description" "$CONFIG_FILE")
        
        # Find matching files
        while IFS= read -r -d '' file; do
            if [[ -f "$file" && "$(basename "$file")" == $pattern ]]; then
                if execute_sql_file "$file" "$description"; then
                    ((files_deployed++))
                fi
            fi
        done < <(find "$schema_path" -name "$pattern" -print0 2>/dev/null || true)
        
    done < <(yq eval '.object_types[] | [.priority, .name] | join(" ")' "$CONFIG_FILE" | sort -n | cut -d' ' -f2-)
    
    log "✅ Schema $schema_name deployed: $files_deployed files"
    return 0
}

# Deploy a domain
deploy_domain() {
    local domain_name="$1"
    
    log "🏗️ Deploying domain: $domain_name"
    
    # Handle foundation domain
    if [ "$domain_name" == "foundation" ]; then
        while IFS= read -r file; do
            if [ "$file" != "null" ]; then
                execute_sql_file "$file" "Foundation setup"
            fi
        done < <(yq eval '.domains[] | select(.name == "foundation") | .files[]' "$CONFIG_FILE")
        return 0
    fi
    
    # Handle permissions domain
    if [ "$domain_name" == "permissions" ]; then
        while IFS= read -r file; do
            if [ "$file" != "null" ]; then
                execute_sql_file "$file" "Permissions"
            fi
        done < <(yq eval '.domains[] | select(.name == "permissions") | .files[]' "$CONFIG_FILE")
        return 0
    fi
    
    # Handle schema-based domains
    while IFS= read -r schema_name; do
        if [ "$schema_name" != "null" ]; then
            local schema_path=$(yq eval ".domains[] | select(.name == \"$domain_name\") | .schemas[] | select(.name == \"$schema_name\") | .path" "$CONFIG_FILE")
            
            if [ "$schema_path" != "null" ]; then
                deploy_schema_files "$schema_path" "$schema_name"
            fi
        fi
    done < <(yq eval ".domains[] | select(.name == \"$domain_name\") | .schemas[]?.name" "$CONFIG_FILE")
}

# Main deployment function
main() {
    log "🚀 Starting Snowflake deployment"
    log "Mode: $DEPLOYMENT_MODE"
    
    # Parse configuration
    parse_config
    
    # Set Snowflake context
    log "🔧 Setting Snowflake context"
    snow sql -q "USE DATABASE $DATABASE" --connection default
    snow sql -q "USE WAREHOUSE $WAREHOUSE" --connection default
    
    # Deploy domains in order
    case "$DEPLOYMENT_MODE" in
        "FULL")
            log "💯 Full deployment mode"
            while IFS= read -r domain_name; do
                if [ "$domain_name" != "null" ]; then
                    deploy_domain "$domain_name"
                fi
            done < <(yq eval '.domains[].name' "$CONFIG_FILE")
            ;;
            
        "SCHEMA_SPECIFIC")
            if [ -z "$TARGET_SCHEMAS" ]; then
                error "TARGET_SCHEMAS required for SCHEMA_SPECIFIC mode"
                exit 1
            fi
            log "🎯 Schema-specific deployment: $TARGET_SCHEMAS"
            
            # Deploy foundation first
            deploy_domain "foundation"
            
            # Deploy specified schemas
            IFS=',' read -ra SCHEMA_ARRAY <<< "$TARGET_SCHEMAS"
            for schema in "${SCHEMA_ARRAY[@]}"; do
                schema=$(echo "$schema" | xargs)  # trim whitespace
                log "Deploying schema: $schema"
                
                # Find the domain containing this schema
                local domain_name=$(yq eval ".domains[] | select(.schemas[]?.name == \"$schema\") | .name" "$CONFIG_FILE")
                if [ "$domain_name" != "null" ]; then
                    # Deploy just this schema from the domain
                    local schema_path=$(yq eval ".domains[] | select(.name == \"$domain_name\") | .schemas[] | select(.name == \"$schema\") | .path" "$CONFIG_FILE")
                    deploy_schema_files "$schema_path" "$schema"
                fi
            done
            
            # Deploy permissions last
            deploy_domain "permissions"
            ;;
            
        "INCREMENTAL")
            log "🔄 Incremental deployment (changed files only)"
            warn "INCREMENTAL mode requires git diff integration - implementing basic version"
            
            # For now, fall back to full deployment
            # TODO: Implement git diff logic
            while IFS= read -r domain_name; do
                if [ "$domain_name" != "null" ]; then
                    deploy_domain "$domain_name"
                fi
            done < <(yq eval '.domains[].name' "$CONFIG_FILE")
            ;;
            
        *)
            error "Unknown deployment mode: $DEPLOYMENT_MODE"
            exit 1
            ;;
    esac
    
    # Post-deployment files
    log "📋 Processing post-deployment files"
    if yq eval '.post_deployment[] | select(.condition == "load_sample_data")' "$CONFIG_FILE" > /dev/null 2>&1; then
        local sample_file=$(yq eval '.post_deployment[] | select(.name == "sample_data") | .file' "$CONFIG_FILE")
        if [ "$sample_file" != "null" ] && [ "${LOAD_SAMPLE_DATA:-false}" == "true" ]; then
            execute_sql_file "$sample_file" "Sample data"
        fi
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    log "🎉 Deployment completed successfully!"
}

# Script entry point
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi