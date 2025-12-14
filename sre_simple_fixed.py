#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import asyncio
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv('sre_agent/.env')

# Ensure the provider is set correctly
os.environ['LLM_PROVIDER'] = 'anthropic'

async def simple_sre_test():
    """Simple SRE agent test without the complex multi-agent system."""
    
    try:
        from sre_agent.llm_utils import create_llm_with_error_handling
        
        print("🚀 Starting Simple SRE Agent Test...")
        print(f"Provider: {os.getenv('LLM_PROVIDER')}")
        print(f"API Key: {os.getenv('ANTHROPIC_API_KEY', 'NOT_SET')[:20]}...")
        
        # Create LLM
        llm = create_llm_with_error_handling('anthropic')
        print("✅ LLM created successfully")
        
        # Get user input
        if len(sys.argv) > 1:
            user_query = ' '.join(sys.argv[1:])
        else:
            user_query = input("Enter your SRE query: ")
        
        print(f"\n🤖 Processing: {user_query}")
        
        # Create SRE prompt
        sre_prompt = f"""You are an expert Site Reliability Engineer (SRE) assistant. 

Your role is to help with:
- Infrastructure troubleshooting and monitoring
- Performance analysis and optimization  
- Log analysis and error investigation
- System health checks and diagnostics
- Kubernetes and container orchestration issues
- Database performance and connectivity problems
- Network and security analysis

User Query: {user_query}

Please provide a detailed, actionable response as an SRE expert."""

        # Get response
        response = llm.invoke(sre_prompt)
        
        print("\n" + "="*60)
        print("🔍 SRE AGENT RESPONSE:")
        print("="*60)
        print(response.content)
        print("="*60)
        
        return response.content
        
    except Exception as e:
        print(f"❌ Error: {e}")
        if "credit balance is too low" in str(e):
            print("\n💡 Solution: Add credits to your Anthropic account")
            print("   1. Go to https://console.anthropic.com/")
            print("   2. Navigate to 'Plans & Billing'")
            print("   3. Add credits ($5-10 is enough for testing)")
        elif "invalid x-api-key" in str(e):
            print("\n💡 Solution: Check your API key")
            print("   1. Verify your API key is correct")
            print("   2. Check if it has expired")
            print("   3. Ensure you have credits in your account")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    asyncio.run(simple_sre_test())