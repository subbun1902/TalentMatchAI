import boto3
import os
import sys
import time

def create_lambda():
    print("Starting Lambda creation process...")
    
    # Configuration
    function_name = 'talentmatch-ai'
    role_arn = 'arn:aws:iam::225989360749:role/talentmatch-lambda-role'
    zip_file = 'lambda-deployment.zip'
    region = 'us-east-1'
    
    # Initialize client
    lambda_client = boto3.client('lambda', region_name=region)
    
    # Check if ZIP exists
    if not os.path.exists(zip_file):
        print(f"Error: {zip_file} not found!")
        return False

    # Read ZIP file
    print(f"Reading {zip_file}...")
    with open(zip_file, 'rb') as f:
        zip_content = f.read()
    
    # Check if function exists
    try:
        print(f"Checking if function {function_name} exists...")
        lambda_client.get_function(FunctionName=function_name)
        print(f"Function {function_name} already exists. Updating code...")
        
        lambda_client.update_function_code(
            FunctionName=function_name,
            ZipFile=zip_content
        )
        print("Code updated.")
        
        # Wait for update
        time.sleep(5)
        
        print("Updating configuration...")
        lambda_client.update_function_configuration(
            FunctionName=function_name,
            Runtime='python3.11',
            Handler='lambda_handler.handler',  # Changed to use separate handler file
            Timeout=300,
            MemorySize=2048,
            Environment={
                'Variables': {
                    'BEDROCK_MODEL_ID': 'anthropic.claude-3-sonnet-20240229-v1:0',
                    'PYTHONUNBUFFERED': '1'
                }
            }
        )
        print("Configuration updated.")
        
    except lambda_client.exceptions.ResourceNotFoundException:
        print(f"Function {function_name} does not exist. Creating...")
        try:
            response = lambda_client.create_function(
                FunctionName=function_name,
                Runtime='python3.11',
                Role=role_arn,
                Handler='lambda_handler.handler',  # Changed to use separate handler file
                Code={'ZipFile': zip_content},
                Timeout=300,
                MemorySize=2048,
                EphemeralStorage={'Size': 512},
                Environment={
                    'Variables': {
                        'BEDROCK_MODEL_ID': 'anthropic.claude-3-sonnet-20240229-v1:0',
                        'PYTHONUNBUFFERED': '1'
                    }
                }
            )
            print(f"Function created successfully. ARN: {response['FunctionArn']}")
        except Exception as e:
            print(f"Failed to create function: {str(e)}")
            return False
            
    except Exception as e:
        print(f"An unexpected error occurred: {str(e)}")
        return False
        
    return True

if __name__ == "__main__":
    success = create_lambda()
    if not success:
        sys.exit(1)
