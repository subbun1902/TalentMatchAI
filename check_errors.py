import boto3
import json
from datetime import datetime

def get_recent_errors():
    logs_client = boto3.client('logs', region_name='us-east-1')
    log_group = '/aws/lambda/talentmatch-ai'
    
    try:
        # Get the most recent log streams
        response = logs_client.describe_log_streams(
            logGroupName=log_group,
            orderBy='LastEventTime',
            descending=True,
            limit=3
        )
        
        if not response['logStreams']:
            print("No log streams found")
            return
        
        print("Searching for errors in recent log streams...\n")
        
        for stream in response['logStreams']:
            log_stream = stream['logStreamName']
            print(f"\n{'='*80}")
            print(f"Log Stream: {log_stream}")
            print('='*80)
            
            # Get log events
            events_response = logs_client.get_log_events(
                logGroupName=log_group,
                logStreamName=log_stream,
                limit=100,
                startFromHead=False
            )
            
            # Filter for error messages
            for event in events_response['events']:
                message = event['message']
                if 'error' in message.lower() or 'exception' in message.lower() or 'traceback' in message.lower():
                    timestamp = datetime.fromtimestamp(event['timestamp'] / 1000)
                    print(f"\n[{timestamp}]")
                    print(message)
        
    except Exception as e:
        print(f"Error reading logs: {e}")

if __name__ == "__main__":
    get_recent_errors()
