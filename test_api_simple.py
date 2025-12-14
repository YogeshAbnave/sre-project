#!/usr/bin/env python3

import os
import requests
from dotenv import load_dotenv

# Load environment variables
load_dotenv('sre_agent/.env')

def test_anthropic_api():
    """Test the Anthropic API key and provide detailed diagnostics."""
    
    api_key = os.getenv('ANTHROPIC_API_KEY')
    
    print("🔍 API Key Diagnostics:")
    print(f"API Key found: {'Yes' if api_key else 'No'}")
    if api_key:
        print(f"API Key format: {api_key[:20]}...{api_key[-10:]}")
        print(f"API Key length: {len(api_key)}")
        print(f"Starts with sk-ant-api03: {'Yes' if api_key.startswith('sk-ant-api03') else 'No'}")
    
    if not api_key:
        print("❌ No API key found in environment")
        return False
    
    print(f"\n🧪 Testing API key...")
    
    headers = {
        'Content-Type': 'application/json',
        'x-api-key': api_key,
        'anthropic-version': '2023-06-01'
    }
    
    data = {
        'model': 'claude-3-haiku-20240307',
        'max_tokens': 50,
        'messages': [{'role': 'user', 'content': 'Say "API test successful"'}]
    }
    
    try:
        response = requests.post(
            'https://api.anthropic.com/v1/messages',
            headers=headers,
            json=data,
            timeout=30
        )
        
        print(f"Response status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ API key is working!")
            print(f"Response: {result['content'][0]['text']}")
            return True
        else:
            print(f"❌ API request failed: {response.status_code}")
            try:
                error_data = response.json()
                print(f"Error details: {error_data}")
                
                if 'error' in error_data:
                    error_type = error_data['error'].get('type', 'unknown')
                    error_message = error_data['error'].get('message', 'no message')
                    
                    if error_type == 'authentication_error':
                        print("\n💡 Authentication Error Solutions:")
                        print("1. Check if your API key is correct")
                        print("2. Verify your API key hasn't expired")
                        print("3. Ensure you copied the full key")
                    elif 'credit' in error_message.lower():
                        print("\n💡 Credit Balance Solutions:")
                        print("1. Go to https://console.anthropic.com/")
                        print("2. Navigate to Plans & Billing")
                        print("3. Add credits ($5-10 for testing)")
                        print("4. Check your current balance")
                    
            except:
                print(f"Raw response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Request failed: {e}")
        return False

if __name__ == "__main__":
    test_anthropic_api()