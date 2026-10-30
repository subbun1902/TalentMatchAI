import boto3
import sys
import os

# Add the package directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'package'))

# Now we can import from app_simple
from app_simple import app, logger

def handler(event, context):
    """
    AWS Lambda handler function for API Gateway events.
    Routes requests to the Flask application.
    """
    import json
    from io import BytesIO
    import base64
    from werkzeug.wrappers import Response as WerkzeugResponse
    
    try:
        # Log the event for debugging
        logger.info(f"Lambda handler invoked. Event keys: {list(event.keys())}")
        
        # Handle API Gateway event
        http_method = event.get('httpMethod', event.get('requestContext', {}).get('http', {}).get('method', 'GET'))
        path = event.get('path', event.get('rawPath', '/'))
        headers = event.get('headers', {})
        query_params = event.get('queryStringParameters', {}) or {}
        body = event.get('body', '')
        
        # Handle base64 encoded body
        if event.get('isBase64Encoded', False):
            body = base64.b64decode(body)
        
        # Build query string
        query_string = '&'.join([f"{k}={v}" for k, v in query_params.items()])
        
        # Ensure headers are strings
        headers = {k: str(v) for k, v in headers.items()}
        
        # Create WSGI environment
        environ = {
            'REQUEST_METHOD': http_method,
            'SCRIPT_NAME': '',
            'PATH_INFO': path,
            'QUERY_STRING': query_string,
            'CONTENT_TYPE': headers.get('content-type', ''),
            'CONTENT_LENGTH': str(len(body)) if body else '0',
            'SERVER_NAME': 'lambda',
            'SERVER_PORT': '443',
            'SERVER_PROTOCOL': 'HTTP/1.1',
            'wsgi.version': (1, 0),
            'wsgi.url_scheme': 'https',
            'wsgi.input': BytesIO(body.encode() if isinstance(body, str) else body),
            'wsgi.errors': BytesIO(),
            'wsgi.multiprocess': False,
            'wsgi.multithread': False,
            'wsgi.run_once': False,
        }
        
        # Add headers to environ
        for key, value in headers.items():
            key = key.upper().replace('-', '_')
            if key not in ('CONTENT_TYPE', 'CONTENT_LENGTH'):
                environ[f'HTTP_{key}'] = value
        
        # Call Flask app
        with app.request_context(environ):
            try:
                response = app.full_dispatch_request()
            except Exception as e:
                logger.error(f"Error in Flask dispatch: {e}", exc_info=True)
                # Check if the exception has a response attribute (Flask error)
                if hasattr(e, 'get_response'):
                    response = e.get_response(environ)
                else:
                    return {
                        'statusCode': 500,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps({'error': 'Internal server error', 'details': str(e)})
                    }
        
        # Ensure response is a Response object
        if not hasattr(response, 'get_data'):
            logger.error(f"Invalid response type: {type(response)}, value: {response}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Invalid response type', 'type': str(type(response))})
            }
        
        # Convert Flask response to API Gateway format
        response_body = response.get_data()
        is_base64 = False
        
        # If response is binary, base64 encode it
        try:
            response_body_str = response_body.decode('utf-8')
        except UnicodeDecodeError:
            response_body_str = base64.b64encode(response_body).decode('utf-8')
            is_base64 = True
        
        # Convert headers to plain dict
        response_headers = {}
        for key, value in response.headers:
            response_headers[key] = value
        
        result = {
            'statusCode': response.status_code,
            'headers': response_headers,
            'body': response_body_str,
            'isBase64Encoded': is_base64
        }
        
        logger.info(f"Returning response with status {response.status_code}")
        return result
        
    except Exception as e:
        # Catch-all for any unexpected errors
        logger.error(f"Unexpected error in Lambda handler: {e}", exc_info=True)
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': 'Lambda handler error',
                'message': str(e),
                'type': str(type(e))
            })
        }

