#!/usr/bin/env python3
"""Debug script to check what config is being loaded."""

import sys
import os
sys.path.insert(0, '.')

from aws_setup.config_manager import ConfigurationManager

def main():
    print("=== Config Debug ===")
    print(f"Current working directory: {os.getcwd()}")
    print(f"Config file exists: {os.path.exists('config.yaml')}")
    
    if os.path.exists('config.yaml'):
        with open('config.yaml', 'r') as f:
            content = f.read()
            print(f"Config file content:\n{content}")
    
    try:
        config_manager = ConfigurationManager('.')
        config = config_manager.load_config()
        print(f"Loaded config: {config}")
        
        print(f"gateway_name in config: {'gateway_name' in config}")
        if 'gateway_name' in config:
            print(f"gateway_name value: '{config['gateway_name']}'")
            print(f"gateway_name is empty: {not config['gateway_name']}")
        
        result = config_manager.validate_config(config)
        print(f"Validation result: {result.status}")
        if result.errors:
            print("Validation errors:")
            for error in result.errors:
                print(f"  - {error.field}: {error.message}")
                
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()