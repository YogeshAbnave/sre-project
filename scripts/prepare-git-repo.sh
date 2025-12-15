#!/bin/bash

# Prepare Git Repository Script
# This script prepares your local SRE Agent project for Git deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --repo URL          Git repository URL"
    echo "  --init              Initialize new Git repository"
    echo "  --help, -h          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --init"
    echo "  $0 --repo https://github.com/user/sre-agent.git"
    echo "  $0 --repo git@github.com:user/sre-agent.git"
}

# Parse command line arguments
GIT_REPO=""
INIT_REPO=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            GIT_REPO="$2"
            shift 2
            ;;
        --init)
            INIT_REPO=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to check if Git is installed
check_git() {
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed. Please install Git first."
        exit 1
    fi
    log_success "Git is available"
}

# Function to check if we're in a project directory
check_project_directory() {
    if [ ! -f "pyproject.toml" ] || [ ! -d "sre_agent" ]; then
        log_error "This doesn't appear to be the SRE Agent project directory"
        log_error "Please run this script from the root of your SRE Agent project"
        exit 1
    fi
    log_success "Project directory verified"
}

# Function to create/update .gitignore
create_gitignore() {
    log_info "Creating/updating .gitignore file..."
    
    cat > .gitignore << 'EOF'
# Environment files
.env
*.env
!.env.example

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Virtual environments
.venv/
venv/
ENV/
env/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# AWS and sensitive files
*.pem
*.key
.aws/
.credentials_provider
.gateway_uri
.access_token
.agent_arn
.memory_id
.cognito_config

# Temporary files
*.tmp
*.temp
.cache/

# Node modules (if any)
node_modules/

# Coverage reports
htmlcov/
.coverage
.pytest_cache/

# Backup files
*.backup.*

# Local development files
local/
.local/
EOF
    
    log_success ".gitignore file created/updated"
}

# Function to initialize Git repository
init_git_repo() {
    log_info "Initializing Git repository..."
    
    if [ -d ".git" ]; then
        log_warning "Git repository already exists"
        return
    fi
    
    git init
    log_success "Git repository initialized"
}

# Function to add remote repository
add_remote() {
    local repo_url="$1"
    
    log_info "Adding remote repository: $repo_url"
    
    # Check if remote already exists
    if git remote get-url origin &> /dev/null; then
        log_warning "Remote 'origin' already exists. Updating URL..."
        git remote set-url origin "$repo_url"
    else
        git remote add origin "$repo_url"
    fi
    
    log_success "Remote repository configured"
}

# Function to check Git configuration
check_git_config() {
    log_info "Checking Git configuration..."
    
    local user_name=$(git config --global user.name 2>/dev/null || echo "")
    local user_email=$(git config --global user.email 2>/dev/null || echo "")
    
    if [ -z "$user_name" ] || [ -z "$user_email" ]; then
        log_warning "Git user configuration is incomplete"
        echo ""
        echo "Please configure Git with your information:"
        echo "  git config --global user.name \"Your Name\""
        echo "  git config --global user.email \"your.email@example.com\""
        echo ""
        read -p "Do you want to configure Git now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter your name: " name
            read -p "Enter your email: " email
            git config --global user.name "$name"
            git config --global user.email "$email"
            log_success "Git configuration updated"
        else
            log_warning "Please configure Git before committing"
        fi
    else
        log_success "Git configuration is complete"
        echo "  Name: $user_name"
        echo "  Email: $user_email"
    fi
}

# Function to stage files
stage_files() {
    log_info "Staging files for commit..."
    
    # Add all files except those in .gitignore
    git add .
    
    # Show what will be committed
    echo ""
    log_info "Files to be committed:"
    git status --porcelain | head -20
    
    local file_count=$(git status --porcelain | wc -l)
    if [ "$file_count" -gt 20 ]; then
        echo "... and $((file_count - 20)) more files"
    fi
    
    log_success "Files staged for commit"
}

# Function to create initial commit
create_initial_commit() {
    log_info "Creating initial commit..."
    
    # Check if there are any commits
    if git rev-parse --verify HEAD &> /dev/null; then
        log_warning "Repository already has commits. Skipping initial commit."
        return
    fi
    
    # Create initial commit
    git commit -m "Initial commit: SRE Agent production deployment

- Added complete CloudFormation infrastructure template
- Added production deployment scripts with Git integration
- Added comprehensive validation framework
- Added complete documentation suite
- Added IAM policies and security configurations
- Added Git-based deployment workflow
- Ready for production deployment on AWS EC2

Features:
- CloudFormation template for complete AWS infrastructure
- Automated deployment scripts with error handling
- SSL certificate management with Let's Encrypt
- Bedrock AgentCore integration
- Cognito authentication
- S3 storage for schemas
- CloudWatch monitoring
- Comprehensive validation and testing
- Git-based deployment workflow"
    
    log_success "Initial commit created"
}

# Function to push to remote
push_to_remote() {
    log_info "Pushing to remote repository..."
    
    # Check if remote exists
    if ! git remote get-url origin &> /dev/null; then
        log_error "No remote repository configured"
        log_error "Please add a remote repository first"
        return 1
    fi
    
    # Get current branch
    local current_branch=$(git branch --show-current)
    
    # Push to remote
    if git push -u origin "$current_branch"; then
        log_success "Successfully pushed to remote repository"
    else
        log_error "Failed to push to remote repository"
        log_error "Please check your Git credentials and repository permissions"
        return 1
    fi
}

# Function to display summary
display_summary() {
    log_info "🎉 Git repository preparation completed!"
    echo ""
    echo "📋 Repository Summary:"
    if git remote get-url origin &> /dev/null; then
        echo "  Remote URL: $(git remote get-url origin)"
    fi
    echo "  Current branch: $(git branch --show-current)"
    if git rev-parse --verify HEAD &> /dev/null; then
        echo "  Latest commit: $(git log --oneline -1)"
    fi
    echo ""
    echo "🚀 Next Steps:"
    echo "  1. Verify your code is pushed to the remote repository"
    echo "  2. Deploy CloudFormation infrastructure on AWS"
    echo "  3. Connect to your EC2 instance"
    echo "  4. Run the Git deployment script:"
    echo "     curl -sSL https://raw.githubusercontent.com/user/repo/main/scripts/git-deploy.sh | bash -s -- --repo $(git remote get-url origin 2>/dev/null || echo 'YOUR_REPO_URL')"
    echo ""
    echo "📖 Documentation:"
    echo "  - See docs/git-deployment-guide.md for detailed instructions"
    echo "  - See docs/cloudformation-deployment-guide.md for infrastructure setup"
    echo "  - See docs/complete-aws-deployment-summary.md for overview"
}

# Main function
main() {
    log_info "🚀 Preparing SRE Agent project for Git deployment"
    echo ""
    
    check_git
    check_project_directory
    create_gitignore
    
    if [ "$INIT_REPO" = true ]; then
        init_git_repo
    fi
    
    if [ -n "$GIT_REPO" ]; then
        if [ "$INIT_REPO" = true ] || [ ! -d ".git" ]; then
            init_git_repo
        fi
        add_remote "$GIT_REPO"
    fi
    
    check_git_config
    stage_files
    
    # Ask user if they want to commit
    echo ""
    read -p "Do you want to create a commit now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_initial_commit
        
        # Ask user if they want to push
        if git remote get-url origin &> /dev/null; then
            echo ""
            read -p "Do you want to push to remote repository now? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                push_to_remote
            fi
        fi
    fi
    
    display_summary
    log_success "🎉 Git repository preparation completed!"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi