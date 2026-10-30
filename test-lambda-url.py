#!/usr/bin/env python3
"""
Test script for Lambda Function URL deployment validation
Tests the deployed Lambda function and diagnoses issues
"""

import requests
import json
import time
import sys
from urllib.parse import urljoin
import urllib3

# Disable SSL warnings for testing
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Lambda Function URL
LAMBDA_URL = "https://7ngwybqpgjq6yp3a5ele2zqbd40vgwlx.lambda-url.us-east-1.on.aws/"

def test_endpoint(url, method="GET", data=None, files=None, timeout=30):
    """Test a specific endpoint and return detailed results"""
    try:
        print(f"\n🔍 Testing {method} {url}")
        
        if method == "GET":
            response = requests.get(url, timeout=timeout, verify=False)
        elif method == "POST":
            if files:
                response = requests.post(url, data=data, files=files, timeout=timeout, verify=False)
            else:
                response = requests.post(url, json=data, timeout=timeout, verify=False)
        
        print(f"✅ Status Code: {response.status_code}")
        print(f"📋 Headers: {dict(response.headers)}")
        
        # Try to parse response
        try:
            if response.headers.get('content-type', '').startswith('application/json'):
                content = response.json()
                print(f"📄 JSON Response: {json.dumps(content, indent=2)}")
            else:
                content = response.text[:500]  # First 500 chars
                print(f"📄 Text Response: {content}")
        except Exception as e:
            print(f"⚠️  Could not parse response: {e}")
            print(f"📄 Raw Response: {response.text[:200]}")
        
        return response.status_code == 200, response
        
    except requests.exceptions.Timeout:
        print(f"⏰ Timeout after {timeout}s")
        return False, None
    except requests.exceptions.ConnectionError as e:
        print(f"🔌 Connection Error: {e}")
        return False, None
    except Exception as e:
        print(f"❌ Error: {e}")
        return False, None

def main():
    """Run comprehensive Lambda function tests"""
    print("🚀 Lambda Function URL Validation")
    print("=" * 50)
    print(f"Testing URL: {LAMBDA_URL}")
    
    # Test 1: Root endpoint
    print("\n1️⃣ Testing root endpoint...")
    success, response = test_endpoint(LAMBDA_URL)
    
    # Test 2: Health check endpoint
    print("\n2️⃣ Testing health check endpoint...")
    health_url = urljoin(LAMBDA_URL, "/api/status")
    success, response = test_endpoint(health_url)
    
    # Test 3: Analyze endpoint (GET)
    print("\n3️⃣ Testing analyze endpoint (GET)...")
    analyze_url = urljoin(LAMBDA_URL, "/analyze")
    success, response = test_endpoint(analyze_url)
    
    # Test 4: Upload endpoints
    print("\n4️⃣ Testing upload endpoints...")
    upload_resume_url = urljoin(LAMBDA_URL, "/upload/resumes")
    success, response = test_endpoint(upload_resume_url)
    
    upload_job_url = urljoin(LAMBDA_URL, "/upload/job-description")
    success, response = test_endpoint(upload_job_url)
    
    # Test 5: Check if Lambda is cold starting
    print("\n5️⃣ Testing cold start behavior...")
    start_time = time.time()
    success, response = test_endpoint(LAMBDA_URL)
    end_time = time.time()
    print(f"⏱️  Response time: {end_time - start_time:.2f}s")
    
    print("\n" + "=" * 50)
    print("🏁 Validation Complete")
    
    # Provide troubleshooting suggestions
    print("\n🔧 Troubleshooting Suggestions:")
    print("1. Check Lambda function logs in CloudWatch")
    print("2. Verify Lambda function timeout settings (should be 300s)")
    print("3. Check Lambda function memory settings (should be 2048MB)")
    print("4. Verify IAM permissions for Bedrock access")
    print("5. Check if Lambda Web Adapter is properly configured")

if __name__ == "__main__":
    main()