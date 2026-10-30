#!/usr/bin/env python3
"""
Test script for Lambda Bedrock connectivity
Tests AWS Bedrock integration from Lambda environment
"""

import json
import boto3
import os
import sys
import logging
from datetime import datetime
from botocore.exceptions import ClientError, NoCredentialsError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def test_aws_credentials():
    """Test AWS credentials and permissions"""
    logger.info("Testing AWS credentials...")
    
    try:
        # Test STS access
        sts_client = boto3.client('sts')
        identity = sts_client.get_caller_identity()
        
        logger.info(f"AWS Identity: {identity.get('Arn', 'Unknown')}")
        logger.info(f"Account ID: {identity.get('Account', 'Unknown')}")
        logger.info(f"User ID: {identity.get('UserId', 'Unknown')}")
        
        return True
        
    except NoCredentialsError:
        logger.error("AWS credentials not found")
        return False
    except ClientError as e:
        logger.error(f"AWS credential error: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error testing credentials: {e}")
        return False

def test_bedrock_access():
    """Test Bedrock service access and model availability"""
    logger.info("Testing Bedrock service access...")
    
    try:
        region = os.getenv('AWS_REGION', 'us-east-1')
        model_id = os.getenv('BEDROCK_MODEL_ID', 'anthropic.claude-3-sonnet-20240229-v1:0')
        
        # Create Bedrock client
        bedrock_client = boto3.client('bedrock', region_name=region)
        
        # List available models
        logger.info("Listing available Bedrock models...")
        response = bedrock_client.list_foundation_models()
        
        available_models = [model['modelId'] for model in response.get('modelSummaries', [])]
        logger.info(f"Found {len(available_models)} available models")
        
        # Check if our target model is available
        if model_id in available_models:
            logger.info(f"✓ Target model {model_id} is available")
        else:
            logger.warning(f"✗ Target model {model_id} not found in available models")
            logger.info("Available models:")
            for model in available_models[:10]:  # Show first 10
                logger.info(f"  - {model}")
        
        return True
        
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', 'Unknown')
        if error_code == 'AccessDeniedException':
            logger.error("Access denied to Bedrock service. Check IAM permissions.")
        else:
            logger.error(f"Bedrock access error ({error_code}): {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error testing Bedrock access: {e}")
        return False

def test_bedrock_runtime():
    """Test Bedrock runtime for model invocation"""
    logger.info("Testing Bedrock runtime...")
    
    try:
        region = os.getenv('AWS_REGION', 'us-east-1')
        model_id = os.getenv('BEDROCK_MODEL_ID', 'anthropic.claude-3-sonnet-20240229-v1:0')
        
        # Create Bedrock runtime client
        bedrock_runtime = boto3.client('bedrock-runtime', region_name=region)
        
        # Simple test prompt
        test_prompt = "Hello, this is a test. Please respond with 'Test successful'."
        
        request_body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 100,
            "temperature": 0.0,
            "messages": [
                {
                    "role": "user",
                    "content": test_prompt
                }
            ]
        }
        
        logger.info(f"Invoking model {model_id}...")
        response = bedrock_runtime.invoke_model(
            modelId=model_id,
            body=json.dumps(request_body),
            contentType='application/json'
        )
        
        # Parse response
        response_body = json.loads(response['body'].read())
        
        if 'content' in response_body and response_body['content']:
            response_text = response_body['content'][0]['text']
            logger.info(f"✓ Model response: {response_text}")
            return True
        else:
            logger.error("✗ Invalid response structure from model")
            return False
            
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', 'Unknown')
        if error_code == 'AccessDeniedException':
            logger.error("Access denied to Bedrock runtime. Check IAM permissions.")
        elif error_code == 'ValidationException':
            logger.error("Model validation error. Check model ID and request format.")
        else:
            logger.error(f"Bedrock runtime error ({error_code}): {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error testing Bedrock runtime: {e}")
        return False

def test_cloudwatch_logs():
    """Test CloudWatch Logs access"""
    logger.info("Testing CloudWatch Logs access...")
    
    try:
        region = os.getenv('AWS_REGION', 'us-east-1')
        function_name = os.getenv('AWS_LAMBDA_FUNCTION_NAME', 'talentmatch-ai')
        
        # Create CloudWatch Logs client
        logs_client = boto3.client('logs', region_name=region)
        
        # Check log group
        log_group_name = f"/aws/lambda/{function_name}"
        
        try:
            response = logs_client.describe_log_groups(
                logGroupNamePrefix=log_group_name
            )
            
            log_groups = response.get('logGroups', [])
            if log_groups:
                logger.info(f"✓ Log group {log_group_name} exists")
                log_group = log_groups[0]
                logger.info(f"  Retention: {log_group.get('retentionInDays', 'Never expire')} days")
                logger.info(f"  Size: {log_group.get('storedBytes', 0)} bytes")
            else:
                logger.warning(f"✗ Log group {log_group_name} not found")
                
        except ClientError as e:
            if e.response.get('Error', {}).get('Code') == 'ResourceNotFoundException':
                logger.warning(f"Log group {log_group_name} not found")
            else:
                raise
        
        # Test log writing capability
        logger.info("Testing log write capability...")
        test_message = f"Test log entry from connectivity test at {datetime.now().isoformat()}"
        logger.info(test_message)
        logger.info("✓ Log writing capability confirmed")
        
        return True
        
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', 'Unknown')
        if error_code == 'AccessDeniedException':
            logger.error("Access denied to CloudWatch Logs. Check IAM permissions.")
        else:
            logger.error(f"CloudWatch Logs error ({error_code}): {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error testing CloudWatch Logs: {e}")
        return False

def test_environment_variables():
    """Test required environment variables"""
    logger.info("Testing environment variables...")
    
    required_vars = [
        'AWS_REGION',
        'BEDROCK_MODEL_ID'
    ]
    
    optional_vars = [
        'AWS_LWA_INVOKE_MODE',
        'AWS_LWA_PORT',
        'PYTHONUNBUFFERED',
        'MAX_TOKENS',
        'TEMPERATURE'
    ]
    
    all_good = True
    
    # Check required variables
    for var in required_vars:
        value = os.getenv(var)
        if value:
            logger.info(f"✓ {var}: {value}")
        else:
            logger.error(f"✗ {var}: Not set (required)")
            all_good = False
    
    # Check optional variables
    for var in optional_vars:
        value = os.getenv(var)
        if value:
            logger.info(f"✓ {var}: {value}")
        else:
            logger.info(f"- {var}: Not set (optional)")
    
    return all_good

def run_comprehensive_test():
    """Run comprehensive connectivity test"""
    logger.info("=" * 60)
    logger.info("LAMBDA BEDROCK CONNECTIVITY TEST")
    logger.info("=" * 60)
    logger.info(f"Test started at: {datetime.now().isoformat()}")
    logger.info(f"Python version: {sys.version}")
    logger.info(f"Boto3 version: {boto3.__version__}")
    logger.info("=" * 60)
    
    tests = [
        ("Environment Variables", test_environment_variables),
        ("AWS Credentials", test_aws_credentials),
        ("Bedrock Service Access", test_bedrock_access),
        ("Bedrock Runtime", test_bedrock_runtime),
        ("CloudWatch Logs", test_cloudwatch_logs)
    ]
    
    results = {}
    
    for test_name, test_func in tests:
        logger.info(f"\n--- {test_name} ---")
        try:
            results[test_name] = test_func()
        except Exception as e:
            logger.error(f"Test {test_name} failed with exception: {e}")
            results[test_name] = False
    
    # Summary
    logger.info("\n" + "=" * 60)
    logger.info("TEST RESULTS SUMMARY")
    logger.info("=" * 60)
    
    passed = 0
    total = len(results)
    
    for test_name, result in results.items():
        status = "PASS" if result else "FAIL"
        logger.info(f"{test_name}: {status}")
        if result:
            passed += 1
    
    logger.info("=" * 60)
    logger.info(f"Overall: {passed}/{total} tests passed")
    
    if passed == total:
        logger.info("✓ All tests passed! Lambda Bedrock connectivity is working.")
        return True
    else:
        logger.error(f"✗ {total - passed} test(s) failed. Check configuration and permissions.")
        return False

def lambda_handler(event, context):
    """Lambda handler for running the test"""
    try:
        success = run_comprehensive_test()
        
        return {
            'statusCode': 200 if success else 500,
            'body': json.dumps({
                'success': success,
                'message': 'Connectivity test completed',
                'timestamp': datetime.now().isoformat()
            })
        }
    except Exception as e:
        logger.error(f"Lambda handler error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            })
        }

if __name__ == '__main__':
    # Run as standalone script
    success = run_comprehensive_test()
    sys.exit(0 if success else 1)