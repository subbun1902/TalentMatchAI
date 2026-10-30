#!/usr/bin/env python3
"""
Test template rendering locally to ensure it works
"""

from app_simple import app

def test_template_rendering():
    """Test if the template renders correctly"""
    with app.test_client() as client:
        response = client.get('/')
        print(f"Status Code: {response.status_code}")
        print(f"Content Length: {len(response.data)}")
        print(f"Content Type: {response.content_type}")
        
        if response.status_code == 200:
            content = response.data.decode('utf-8')
            if 'TalentMatch AI' in content:
                print("✅ Template renders correctly locally")
                print(f"📄 Content preview: {content[:200]}...")
            else:
                print("❌ Template content is missing expected elements")
        else:
            print(f"❌ Template rendering failed with status {response.status_code}")

if __name__ == "__main__":
    test_template_rendering()