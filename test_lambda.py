import boto3
import json
import base64

def test_lambda():
    client = boto3.client('lambda', region_name='us-east-1')
    
    payload = {
        "httpMethod": "GET",
        "path": "/api/status",
        "headers": {},
        "queryStringParameters": {},
        "body": ""
    }
    
    print("Invoking Lambda function...")
    try:
        response = client.invoke(
            FunctionName='talentmatch-ai',
            InvocationType='RequestResponse',
            Payload=json.dumps(payload)
        )
        
        response_payload = json.loads(response['Payload'].read().decode('utf-8'))
        print("\nResponse Status Code:", response['StatusCode'])
        print("Function Error:", response.get('FunctionError', 'None'))
        print("\nResponse Payload:")
        print(json.dumps(response_payload, indent=2))
        
        if 'body' in response_payload:
            body = response_payload['body']
            if response_payload.get('isBase64Encoded', False):
                body = base64.b64decode(body).decode('utf-8')
            print("\nDecoded Body:", body)
            
    except Exception as e:
        print(f"Error invoking Lambda: {e}")

if __name__ == "__main__":
    test_lambda()
