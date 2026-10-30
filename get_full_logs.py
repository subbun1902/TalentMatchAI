import boto3
import json
from datetime import datetime

def get_latest_errors():
    logs_client = boto3.client('logs', region_name='us-east-1')
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
        print(f"Most recent log stream: {log_stream}\n")
        
        # Get the last 100 log events
        events_response = logs_client.get_log_events(
            logGroupName=log_group,
            logStreamName=log_stream,
            limit=100,
            startFromHead=False
        )
        
        print("Recent log events (last 100):")
        print("=" * 100)
        for event in events_response['events']:
            timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
            message = event['message']
            # Print all messages to see the full context
            print(f"[{timestamp}] {message}")
        
    except Exception as e:
        print(f"Error reading logs: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    get_latest_errors()
