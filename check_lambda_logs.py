import boto3
import json
from datetime import datetime, timedelta

def get_lambda_logs():
    logs_client = boto3.client('logs', region_name='us-east-1')
    
    # Get log streams for the Lambda function
    log_group = '/aws/lambda/talentmatch-ai'
    
    try:
        # Get the most recent log stream
        response = logs_client.describe_log_streams(
            logGroupName=log_group,
            orderBy='LastEventTime',
            descending=True,
            limit=1
        )
        
        if not response['logStreams']:
            print("No log streams found")
            return
            
        log_stream = response['logStreams'][0]['logStreamName']
        print(f"Reading from log stream: {log_stream}\n")
        
        # Get the last 50 log events
        events_response = logs_client.get_log_events(
            logGroupName=log_group,
            logStreamName=log_stream,
            limit=50,
            startFromHead=False
        )
        
        print("Recent log events:")
        print("=" * 80)
        for event in events_response['events']:
            timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
            print(f"[{timestamp}] {event['message']}")
        
    except Exception as e:
        print(f"Error reading logs: {e}")

if __name__ == "__main__":
    get_lambda_logs()
