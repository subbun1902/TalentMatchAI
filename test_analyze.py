import boto3
import json

def test_analyze_endpoint():
    """Test the analyze endpoint directly"""
    lambda_client = boto3.client('lambda', region_name='us-east-1')
    
    # Create a test payload for analysis
    payload = {
        "httpMethod": "POST",
        "path": "/api/analyze",
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps({
            # Empty or minimal data to trigger an error
            "test": "data"
        })
    }
    
    print("Testing /api/analyze endpoint...")
    print("="*80)
    
    try:
        response = lambda_client.invoke(
            FunctionName='talentmatch-ai',
            InvocationType='RequestResponse',
            Payload=json.dumps(payload)
        )
        
        response_payload = json.loads(response['Payload'].read().decode('utf-8'))
        
        print(f"Status Code: {response['StatusCode']}")
        print(f"Function Error: {response.get('FunctionError', 'None')}")
        print("\nResponse Payload:")
        print(json.dumps(response_payload, indent=2))
        
        if 'body' in response_payload:
            try:
                body = json.loads(response_payload['body'])
                print("\nDecoded Body:")
                print(json.dumps(body, indent=2))
            except:
                print("\nBody (not JSON):")
                print(response_payload['body'])
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_analyze_endpoint()
