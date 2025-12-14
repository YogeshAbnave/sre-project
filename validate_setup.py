#!/usr/bin/env python3
"""
SRE Agent Setup Validation Script

This script validates your environment and configuration for running the SRE Agent
in production, providing specific guidance for fixing any issues found.
"""

import os
import sys
import subprocess
import json
import yaml
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# Colors for terminal output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

def print_status(message: str, status: str = "info"):
    """Print colored status message."""
    colors = {
        "success": Colors.GREEN + "✅ ",
        "error": Colors.RED + "❌ ",
        "warning": Colors.YELLOW + "⚠️  ",
        "info": Colors.BLUE + "ℹ️  "
    }
    print(f"{colors.get(status, '')}{message}{Colors.NC}")

def run_command(cmd: List[str], capture_output: bool = True) -> Tuple[bool, str]:
    """Run a command and return success status and output."""
    try:
        result = subprocess.run(
            cmd, 
            capture_output=capture_output, 
            text=True, 
            timeout=30
        )
        return result.returncode == 0, result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        return False, str(e)

def check_prerequisites() -> bool:
    """Check if all prerequisites are installed."""
    print_status("Checking Prerequisites", "info")
    
    all_good = True
    
    # Check Python version
    try:
        version = sys.version_info
        if version.major >= 3 and version.minor >= 12:
            print_status(f"Python {version.major}.{version.minor}.{version.micro} - OK", "success")
        else:
            print_status(f"Python {version.major}.{version.minor}.{version.micro} - Need 3.12+", "error")
            all_good = False
    except Exception as e:
        print_status(f"Python check failed: {e}", "error")
        all_good = False
    
    # Check AWS CLI
    success, output = run_command(["aws", "--version"])
    if success:
        print_status(f"AWS CLI - OK ({output.split()[0]})", "success")
    else:
        print_status("AWS CLI - Not installed", "error")
        print("  Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html")
        all_good = False
    
    # Check uv
    success, output = run_command(["uv", "--version"])
    if success:
        print_status(f"uv package manager - OK ({output})", "success")
    else:
        print_status("uv package manager - Not installed", "error")
        print("  Install: curl -LsSf https://astral.sh/uv/install.sh | sh")
        all_good = False
    
    return all_good

def check_aws_credentials() -> bool:
    """Check AWS credentials and permissions."""
    print_status("Checking AWS Credentials", "info")
    
    # Test basic AWS access
    success, output = run_command(["aws", "sts", "get-caller-identity"])
    if not success:
        print_status("AWS credentials not configured or invalid", "error")
        print("  Solutions:")
        print("  1. Run: aws configure")
        print("  2. Set environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY")
        print("  3. Attach IAM role to EC2 instance (recommended)")
        return False
    
    try:
        identity = json.loads(output)
        account_id = identity.get('Account', 'Unknown')
        user_arn = identity.get('Arn', 'Unknown')
        print_status(f"AWS credentials valid - Account: {account_id}", "success")
        print_status(f"User/Role: {user_arn}", "info")
        
        # Test S3 access
        success, _ = run_command(["aws", "s3", "ls"])
        if success:
            print_status("S3 access - OK", "success")
        else:
            print_status("S3 access - Limited permissions", "warning")
            
        return True
        
    except json.JSONDecodeError:
        print_status("Failed to parse AWS identity response", "error")
        return False

def check_configuration() -> bool:
    """Check configuration files."""
    print_status("Checking Configuration Files", "info")
    
    config_file = Path("gateway/config.yaml")
    env_file = Path("gateway/.env")
    
    all_good = True
    
    # Check config.yaml
    if not config_file.exists():
        print_status("config.yaml not found", "error")
        print("  Create from template: cp gateway/config.yaml.example gateway/config.yaml")
        all_good = False
    else:
        try:
            with open(config_file, 'r') as f:
                config = yaml.safe_load(f)
                
            # Check for placeholder values
            placeholders = ['YOUR_ACCOUNT_ID', 'REGION', 'YOUR_ROLE_NAME', 'YOUR_USER_POOL_ID', 'YOUR_CLIENT_ID']
            found_placeholders = []
            
            for key, value in config.items():
                if isinstance(value, str) and value in placeholders:
                    found_placeholders.append(f"{key}: {value}")
                    
            if found_placeholders:
                print_status("config.yaml contains placeholder values", "error")
                for placeholder in found_placeholders:
                    print(f"  - {placeholder}")
                all_good = False
            else:
                print_status("config.yaml - OK", "success")
                
        except yaml.YAMLError as e:
            print_status(f"config.yaml invalid YAML: {e}", "error")
            all_good = False
    
    # Check .env file
    if not env_file.exists():
        print_status(".env file not found", "warning")
        print("  Create from template: cp gateway/.env.example gateway/.env")
    else:
        # Check for required environment variables
        env_vars = {}
        with open(env_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env_vars[key.strip()] = value.strip()
        
        required_vars = ['BACKEND_API_KEY']
        missing_vars = [var for var in required_vars if var not in env_vars or not env_vars[var]]
        
        if missing_vars:
            print_status(f".env missing required variables: {', '.join(missing_vars)}", "error")
            all_good = False
        else:
            print_status(".env file - OK", "success")
    
    return all_good

def check_ssl_certificates() -> bool:
    """Check for SSL certificates."""
    print_status("Checking SSL Certificates", "info")
    
    cert_paths = [
        Path("/opt/ssl/privkey.pem"),
        Path("/opt/ssl/fullchain.pem")
    ]
    
    all_exist = all(path.exists() for path in cert_paths)
    
    if all_exist:
        print_status("SSL certificates found", "success")
        return True
    else:
        print_status("SSL certificates not found", "warning")
        print("  For production, install SSL certificates:")
        print("  1. Use Let's Encrypt: sudo certbot certonly --standalone -d yourdomain.com")
        print("  2. Or create self-signed (testing only):")
        print("     sudo mkdir -p /opt/ssl")
        print("     sudo openssl req -x509 -newkey rsa:4096 -keyout /opt/ssl/privkey.pem -out /opt/ssl/fullchain.pem -days 365 -nodes")
        return False

def check_ports() -> bool:
    """Check if required ports are available."""
    print_status("Checking Port Availability", "info")
    
    required_ports = [8011, 8012, 8013, 8014]
    
    success, output = run_command(["netstat", "-tlnp"])
    if not success:
        print_status("Could not check port availability", "warning")
        return True
    
    used_ports = []
    for line in output.split('\n'):
        for port in required_ports:
            if f":{port} " in line:
                used_ports.append(port)
    
    if used_ports:
        print_status(f"Ports already in use: {used_ports}", "warning")
        print("  Stop existing services or use different ports")
        return False
    else:
        print_status("Required ports available", "success")
        return True

def generate_fix_script() -> None:
    """Generate a script to fix common issues."""
    fix_script = """#!/bin/bash
# Auto-generated fix script for SRE Agent setup issues

echo "🔧 Fixing SRE Agent setup issues..."

# Fix 1: Install missing prerequisites
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi

if ! command -v uv &> /dev/null; then
    echo "Installing uv package manager..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source ~/.bashrc
fi

# Fix 2: Create configuration templates
if [ ! -f "gateway/config.yaml" ]; then
    echo "Creating config.yaml template..."
    cp gateway/config.yaml.example gateway/config.yaml
    echo "⚠️  Please edit gateway/config.yaml with your values"
fi

if [ ! -f "gateway/.env" ]; then
    echo "Creating .env template..."
    cp gateway/.env.example gateway/.env
    echo "⚠️  Please edit gateway/.env with your values"
fi

# Fix 3: Create self-signed SSL certificates (for testing)
if [ ! -f "/opt/ssl/privkey.pem" ]; then
    echo "Creating self-signed SSL certificates..."
    sudo mkdir -p /opt/ssl
    sudo openssl req -x509 -newkey rsa:4096 -keyout /opt/ssl/privkey.pem -out /opt/ssl/fullchain.pem -days 365 -nodes -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
    echo "✅ Self-signed certificates created (for testing only)"
fi

# Fix 4: Configure AWS credentials (interactive)
if ! aws sts get-caller-identity &> /dev/null; then
    echo "AWS credentials not configured. Please run:"
    echo "  aws configure"
    echo "Or attach an IAM role to your EC2 instance"
fi

echo "🎉 Fix script completed!"
echo "Next steps:"
echo "1. Edit gateway/config.yaml with your AWS account details"
echo "2. Edit gateway/.env with your API keys"
echo "3. Run: ./gateway/setup_production.sh"
"""
    
    with open("fix_setup.sh", "w") as f:
        f.write(fix_script)
    
    os.chmod("fix_setup.sh", 0o755)
    print_status("Generated fix_setup.sh script", "success")

def main():
    """Main validation function."""
    print("🔍 SRE Agent Setup Validation")
    print("=" * 50)
    
    checks = [
        ("Prerequisites", check_prerequisites),
        ("AWS Credentials", check_aws_credentials),
        ("Configuration", check_configuration),
        ("SSL Certificates", check_ssl_certificates),
        ("Port Availability", check_ports),
    ]
    
    results = []
    for name, check_func in checks:
        try:
            result = check_func()
            results.append((name, result))
        except Exception as e:
            print_status(f"{name} check failed: {e}", "error")
            results.append((name, False))
        print()  # Add spacing between checks
    
    # Summary
    print("📋 Validation Summary")
    print("=" * 50)
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for name, result in results:
        status = "success" if result else "error"
        print_status(f"{name}: {'PASS' if result else 'FAIL'}", status)
    
    print(f"\nOverall: {passed}/{total} checks passed")
    
    if passed == total:
        print_status("🎉 All checks passed! Ready to run production setup.", "success")
        print("\nNext steps:")
        print("1. Run: ./gateway/setup_production.sh")
        print("2. Or run: chmod +x gateway/setup_production.sh && ./gateway/setup_production.sh")
    else:
        print_status("❌ Some checks failed. Generating fix script...", "error")
        generate_fix_script()
        print("\nTo fix issues:")
        print("1. Run: chmod +x fix_setup.sh && ./fix_setup.sh")
        print("2. Edit configuration files as needed")
        print("3. Re-run this validation: python3 validate_setup.py")
    
    return passed == total

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)