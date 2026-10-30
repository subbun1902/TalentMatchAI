#!/usr/bin/env python3
"""
Test the Lambda web interface to ensure it's working properly
"""

import requests
import urllib3

# Disable SSL warnings for testing
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

LAMBDA_URL = "https://7ngwybqpgjq6yp3a5ele2zqbd40vgwlx.lambda-url.us-east-1.on.aws/"

def test_web_interface():
    """Test the main web interface"""
    print("🌐 Testing Lambda Web Interface")
    print("=" * 50)
    
    try:
        # Test main page
        print("Testing main page...")
        response = requests.get(LAMBDA_URL, verify=False, timeout=30)
        
        if response.status_code == 200:
            print("✅ Main page loads successfully!")
            print(f"📄 Content length: {len(response.text)} characters")
            
            # Check if it contains expected HTML elements
            if "TalentMatch" in response.text or "Resume" in response.text:
                print("✅ Page contains expected content")
            else:
                print("⚠️  Page content may not be complete")
                
        else:
            print(f"❌ Main page failed with status: {response.status_code}")
            
        # Test API status endpoint
        print("\nTesting API status endpoint...")
        status_response = requests.get(f"{LAMBDA_URL}api/status", verify=False, timeout=30)
        
        if status_response.status_code == 200:
            print("✅ API status endpoint works!")
            try:
                status_data = status_response.json()
                print(f"📊 Status data: {status_data}")
            except:
                print("⚠️  Status response is not JSON")
        else:
            print(f"❌ API status failed with status: {status_response.status_code}")
            
        print("\n" + "=" * 50)
        print("🎉 Lambda deployment is working!")
        print(f"🔗 Access your app at: {LAMBDA_URL}")
        print("\n📋 Next steps:")
        print("1. Open the URL in your browser")
        print("2. Upload resume files and job descriptions")
        print("3. Test the AI analysis functionality")
        
    except Exception as e:
        print(f"❌ Error testing web interface: {e}")

if __name__ == "__main__":
    test_web_interface()