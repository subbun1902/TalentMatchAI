"""
AWS Security Service for Resume Analyzer
Simple and clean AWS Bedrock integration.
"""

import boto3
import json
import logging
import time

from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta

import os
from botocore.exceptions import ClientError, NoCredentialsError, PartialCredentialsError

# Configure logging
logger = logging.getLogger(__name__)

class AWSSecurityService:
    """
    Simple AWS Bedrock service for resume analysis
    """
    
    def __init__(self):
        """Initialize AWS security service"""
        self.region = os.getenv('AWS_REGION', 'us-east-1')
        self.model_id = os.getenv('BEDROCK_MODEL_ID', 'anthropic.claude-3-sonnet-20240229-v1:0')
        
        # Optimized configuration for faster processing
        self.max_tokens = int(os.getenv('MAX_TOKENS', '3000'))  # Reduced from 4000
        self.temperature = float(os.getenv('TEMPERATURE', '0.0'))  # More deterministic
        
        # Rate limiting
        self.rate_limit_requests = int(os.getenv('RATE_LIMIT_REQUESTS', '10'))
        self.rate_limit_window = int(os.getenv('RATE_LIMIT_WINDOW', '60'))
        
        # Initialize clients
        self._bedrock_client = None
        self._sts_client = None
        
        # Security tracking
        self.request_history = []
        self.security_events = []
        
        logger.info("AWS security service initialized")
        
        # Validate configuration
        self._validate_configuration()
        
    def _validate_configuration(self):
        """Validate AWS configuration and credentials"""
        try:
            # Validate credentials
            self._validate_credentials()
            
            # Validate model availability
            self._validate_model_availability()
            
            logger.info("AWS security service initialized successfully")
            
        except Exception as e:
            logger.error(f"AWS configuration validation failed: {e}")
            raise
    
    def _validate_credentials(self):
        """Validate AWS credentials"""
        try:
            sts_client = self._get_sts_client()
            identity = sts_client.get_caller_identity()
            
            logger.info(f"AWS credentials validated for: {identity.get('Arn', 'Unknown')}")
            
        except (NoCredentialsError, PartialCredentialsError) as e:
            raise Exception(f"AWS credentials not found or incomplete: {e}")
        except Exception as e:
            raise Exception(f"AWS credential validation failed: {e}")
    
    def _validate_model_availability(self):
        """Validate that the specified model is available"""
        try:
            bedrock_client = self._get_bedrock_client()
            
            # List available models
            response = bedrock_client.list_foundation_models()
            available_models = [model['modelId'] for model in response.get('modelSummaries', [])]
            
            # Check if our model is available
            if self.model_id not in available_models:
                logger.warning(f"Model '{self.model_id}' may not be available")
            
        except Exception as e:
            logger.warning(f"Model availability check failed: {e}")
    
    def _get_bedrock_client(self):
        """Get or create Bedrock client"""
        if self._bedrock_client is None:
            try:
                session = boto3.Session()
                self._bedrock_client = session.client(
                    'bedrock-runtime',
                    region_name=self.region
                )
                
            except Exception as e:
                logger.error(f"Failed to create Bedrock client: {e}")
                raise
        
        return self._bedrock_client
    
    def _get_sts_client(self):
        """Get or create STS client for credential validation"""
        if self._sts_client is None:
            try:
                session = boto3.Session()
                self._sts_client = session.client('sts', region_name=self.region)
            except Exception as e:
                logger.error(f"Failed to create STS client: {e}")
                raise
        
        return self._sts_client
    
    def _check_rate_limit(self) -> bool:
        """Check if request is within rate limits"""
        current_time = datetime.now()
        
        # Clean old requests
        cutoff_time = current_time - timedelta(seconds=self.rate_limit_window)
        self.request_history = [req_time for req_time in self.request_history if req_time > cutoff_time]
        
        # Check rate limit
        if len(self.request_history) >= self.rate_limit_requests:
            logger.warning("Rate limit exceeded")
            return False
        
        # Add current request
        self.request_history.append(current_time)
        return True
    
    def _log_security_event(self, event_type: str, details: Dict[str, Any]):
        """Log security events for monitoring"""
        event = {
            'timestamp': datetime.now().isoformat(),
            'type': event_type,
            'details': details
        }
        
        self.security_events.append(event)
        logger.info(f"Security event: {event_type}")
        
        # Keep only recent events (last 100)
        if len(self.security_events) > 100:
            self.security_events = self.security_events[-100:]
    

    
    def analyze_resume_with_bedrock(self, resume_text: str, job_description: str, analysis_type: str = "comprehensive", filename: str = "unknown") -> Dict[str, Any]:
        """
        Analyze resume using AWS Bedrock
        
        Args:
            resume_text: The resume content to analyze
            job_description: The job description to match against
            analysis_type: Type of analysis (comprehensive, quick, skills_only)
            filename: The original filename
            
        Returns:
            Dict containing analysis results
        """
        start_time = time.time()
        
        logger.info(f"Starting analysis - Type: {analysis_type}, File: {filename}")
        
        try:
            # Security checks
            if not self._check_rate_limit():
                raise Exception("Rate limit exceeded. Please try again later.")
            
            # Input validation
            if not resume_text or not job_description:
                raise ValueError("Both resume text and job description are required")
            
            if len(resume_text) > 50000 or len(job_description) > 10000:
                raise ValueError("Input text too long for security reasons")
            
            # Log security event
            self._log_security_event("bedrock_analysis_request", {
                'analysis_type': analysis_type,
                'resume_length': len(resume_text),
                'job_desc_length': len(job_description)
            })
            
            # Prepare prompt
            prompt = self._create_analysis_prompt(resume_text, job_description, analysis_type, filename)
            
            # Make Bedrock request
            bedrock_client = self._get_bedrock_client()
            
            request_body = {
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": self.max_tokens,
                "temperature": self.temperature,
                "messages": [
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            }
            
            response = bedrock_client.invoke_model(
                modelId=self.model_id,
                body=json.dumps(request_body),
                contentType='application/json'
            )
            
            # Parse response
            response_body = json.loads(response['body'].read())
            
            # Validate response structure
            if 'content' not in response_body or not response_body['content']:
                raise ValueError("Invalid response structure: missing content")
            
            analysis_result = response_body['content'][0]['text']
            
            # Validate response content
            if not analysis_result or len(analysis_result.strip()) == 0:
                raise ValueError("Empty response from Bedrock model")
            
            logger.info(f"Raw Bedrock response length: {len(analysis_result)}")
            logger.debug(f"Response preview: {analysis_result[:200]}...")
            
            # Log successful analysis
            self._log_security_event("bedrock_analysis_success", {
                'analysis_type': analysis_type,
                'response_length': len(analysis_result)
            })
            
            # Parse and structure the result
            structured_result = self._parse_analysis_result(analysis_result, analysis_type)
            
            # Prepare final response
            response = {
                'success': True,
                'analysis': structured_result,
                'raw_response': analysis_result,
                'model_used': self.model_id,
                'analysis_type': analysis_type,
                'filename': filename,
                'timestamp': datetime.now().isoformat()
            }
            
            total_time = time.time() - start_time
            logger.info(f"Analysis completed in {total_time:.2f}s for file: {filename}")
            
            return response
            
        except Exception as e:
            total_time = time.time() - start_time
            logger.error(f"Analysis failed after {total_time:.2f}s for file {filename}: {e}")
            
            # Log security event for failure
            self._log_security_event("bedrock_analysis_failure", {
                'filename': filename,
                'error': str(e),
                'duration': total_time
            })
            
            return {
                'success': False,
                'error': f"AWS Bedrock Analysis Failed: {str(e)}",
                'error_type': 'BEDROCK_ERROR',
                'filename': filename,
                'timestamp': datetime.now().isoformat(),
                'duration': total_time
            }
    
    def _create_analysis_prompt(self, resume_text: str, job_description: str, analysis_type: str, filename: str) -> str:
        """Create analysis prompt for Bedrock"""
        
        base_prompt = f"""You are an expert resume analyzer. Analyze the following resume against the job description and provide a detailed assessment.

FILENAME: {filename}
ANALYSIS TYPE: {analysis_type}

JOB DESCRIPTION:
{job_description}

RESUME:
{resume_text}

ANALYSIS INSTRUCTIONS:
1. Carefully read both the job description and resume
2. Identify key requirements from the job description (skills, experience, education, etc.)
3. Match candidate qualifications against these requirements
4. Calculate match percentages based on how well the candidate meets the requirements
5. Provide specific, actionable feedback

Please provide your analysis in the following JSON format:
{{
    "candidate_info": {{
        "name": "Candidate Name",
        "current_designation": "Senior Software Engineer",
        "current_company": "Tech Corp Inc",
        "email": "email@example.com",
        "phone": "phone number",
        "location": "location"
    }},
    "overall_match_percentage": 85,
    "recommendation": "STRONG_MATCH",
    "skills_analysis": {{
        "skills_match_percentage": 80,
        "required_skills_matched": ["skill1", "skill2"],
        "required_skills_missing": ["skill3", "skill4"],
        "additional_skills": ["skill5", "skill6"]
    }},
    "experience_analysis": {{
        "years_of_experience": 5,
        "relevant_experience": "Description of relevant experience with specific examples",
        "experience_match": "HIGH"
    }},
    "education_analysis": {{
        "education_level": "Bachelor's Degree",
        "relevant_education": "Computer Science",
        "education_match": "HIGH"
    }},
    "strengths": ["strength1", "strength2"],
    "areas_for_improvement": ["area1", "area2"],
    "key_highlights": ["highlight1", "highlight2", "highlight3"],
    "interview_questions": ["What experience do you have with [specific skill]?", "Can you describe a project where you used [technology]?", "How would you approach [relevant scenario]?"],
    "summary_bullets": ["Key point 1 about the candidate", "Key point 2 about their fit", "Key point 3 about their potential"],
    "summary": "Overall assessment summary"
}}

SCORING GUIDELINES:
- overall_match_percentage: 0-100 based on overall fit for the role
- skills_match_percentage: 0-100 based on required skills coverage
- recommendation: STRONG_MATCH (80-100%), GOOD_MATCH (60-79%), WEAK_MATCH (40-59%), POOR_MATCH (0-39%)
- experience_match: HIGH (meets or exceeds requirements), MEDIUM (partially meets), LOW (below requirements)
- education_match: HIGH (meets or exceeds), MEDIUM (acceptable), LOW (below requirements)

SPECIFIC INSTRUCTIONS:
- strengths: List 2-4 key strengths that make this candidate suitable for the role, be specific
- areas_for_improvement: List 2-4 areas where the candidate could improve or lacks experience relative to job requirements
- key_highlights: List 3-5 most impressive achievements, experiences, or qualifications from the resume that are relevant to the job
- interview_questions: Generate 3-5 specific interview questions based on the candidate's background and the job requirements
- Focus interview questions on areas where the candidate shows strength or needs clarification
- Include both technical and behavioral questions when appropriate
- Make questions specific to the candidate's experience and the job requirements
- summary_bullets: Provide 3-4 key bullet points summarizing the candidate's profile and fit for the role
- summary: Provide a concise 2-3 sentence overall assessment of the candidate's fit for the role

IMPORTANT: Base your analysis strictly on the job description requirements and the candidate's qualifications as stated in their resume."""
        
        return base_prompt.strip()
    
    def _parse_analysis_result(self, analysis_result: str, analysis_type: str) -> Dict[str, Any]:
        """Parse the analysis result from Bedrock"""
        json_start = -1
        json_end = -1
        
        try:
            # Clean the response - remove any text before/after JSON
            json_start = analysis_result.find('{')
            json_end = analysis_result.rfind('}') + 1
            
            if json_start != -1 and json_end != -1:
                json_str = analysis_result[json_start:json_end]
                
                # Try multiple parsing approaches
                parsing_attempts = [
                    ("original", json_str),
                    ("fixed", self._fix_common_json_issues(json_str)),
                    ("aggressive_fix", self._aggressive_json_fix(json_str))
                ]
                
                for attempt_name, attempt_json in parsing_attempts:
                    try:
                        logger.debug(f"Trying JSON parsing approach: {attempt_name}")
                        parsed_result = json.loads(attempt_json)
                        
                        # Validate and fix structure
                        parsed_result = self._validate_and_fix_structure(parsed_result)
                        
                        logger.info(f"JSON parsing successful with approach: {attempt_name}")
                        return parsed_result
                        
                    except json.JSONDecodeError as e:
                        logger.warning(f"JSON parsing attempt '{attempt_name}' failed: {e}")
                        # Log more details for debugging
                        if attempt_name == "aggressive_fix":
                            logger.warning(f"Problematic JSON section around error: {attempt_json[max(0, e.pos-100):e.pos+100]}")
                        continue
                
                # If all attempts failed, return error
                logger.warning("All JSON parsing attempts failed")
                return {
                    'parsing_error': True,
                    'error_type': 'JSON_PARSING_ERROR',
                    'error_message': "AWS Bedrock returned invalid JSON - all parsing attempts failed",
                    'raw_response_preview': analysis_result[:500] + "..." if len(analysis_result) > 500 else analysis_result
                }
                
            else:
                logger.warning("No JSON structure found in response")
                return {
                    'parsing_error': True,
                    'error_type': 'NO_JSON_FOUND',
                    'error_message': "AWS Bedrock response does not contain valid JSON structure",
                    'raw_response_preview': analysis_result[:500] + "..." if len(analysis_result) > 500 else analysis_result
                }
                
        except Exception as e:
            logger.error(f"Analysis parsing failed: {e}")
            return {
                'parsing_error': True,
                'error_type': 'PARSING_ERROR',
                'error_message': f"Failed to parse AWS Bedrock response: {str(e)}",
                'raw_response_preview': analysis_result[:500] + "..." if len(analysis_result) > 500 else analysis_result
            }
    
    def _fix_common_json_issues(self, json_str: str) -> str:
        """Fix common JSON formatting issues"""
        import re
        
        # Remove any text before the first { or after the last }
        first_brace = json_str.find('{')
        last_brace = json_str.rfind('}')
        if first_brace != -1 and last_brace != -1:
            json_str = json_str[first_brace:last_brace + 1]
        
        # Remove trailing commas before closing brackets/braces
        json_str = re.sub(r',(\s*[}\]])', r'\1', json_str)
        
        # Fix common quote issues
        json_str = json_str.replace('""', '"')
        
        # Fix unescaped quotes in string values - more comprehensive approach
        # Handle cases like: "summary": "He's a great developer with 5+ years"
        def fix_quotes_in_strings(match):
            key = match.group(1)
            value = match.group(2)
            # Escape internal quotes
            value = value.replace('"', '\\"')
            return f'"{key}": "{value}"'
        
        # Pattern to match key-value pairs with potential quote issues
        json_str = re.sub(r'"([^"]+)":\s*"([^"]*(?:"[^"]*)*)"(?=\s*[,}])', fix_quotes_in_strings, json_str)
        
        # Fix missing commas between objects/arrays
        json_str = re.sub(r'}\s*{', '}, {', json_str)
        json_str = re.sub(r']\s*\[', '], [', json_str)
        
        # Fix missing commas after string values
        json_str = re.sub(r'"\s*\n\s*"', '",\n    "', json_str)
        
        # Fix array formatting issues
        json_str = re.sub(r'\[\s*"([^"]*)"([^,\]]*)\]', r'["\1\2"]', json_str)
        
        return json_str
    
    def _aggressive_json_fix(self, json_str: str) -> str:
        """More aggressive JSON fixing for problematic responses"""
        import re
        
        # Start with basic fixes
        json_str = self._fix_common_json_issues(json_str)
        
        # Fix specific issues that cause parsing errors
        
        # Fix missing quotes around keys
        json_str = re.sub(r'(\w+):', r'"\1":', json_str)
        
        # Fix array elements without proper quotes
        json_str = re.sub(r'\[\s*([^"\[\]{}]+)\s*\]', r'["\1"]', json_str)
        
        # Fix multiple consecutive commas
        json_str = re.sub(r',+', ',', json_str)
        
        # Fix missing commas between array elements
        json_str = re.sub(r'"\s+"', '", "', json_str)
        
        # Fix line breaks in string values
        json_str = re.sub(r'"\s*\n\s*([^"]*)\s*\n\s*"', r'"\1"', json_str)
        
        # Remove any remaining trailing commas
        json_str = re.sub(r',(\s*[}\]])', r'\1', json_str)
        
        return json_str
    

    def _validate_and_fix_structure(self, parsed_result: Dict[str, Any]) -> Dict[str, Any]:
        """Validate and fix the parsed JSON structure"""
        # Ensure job_match_summary exists
        if 'job_match_summary' not in parsed_result:
            parsed_result['job_match_summary'] = {
                'overall_match_percentage': 0,
                'recommendation': 'POOR_MATCH',
                'match_reasoning': 'Unable to determine match'
            }
        
        # Ensure backward compatibility fields exist
        if 'overall_match_percentage' not in parsed_result:
            parsed_result['overall_match_percentage'] = parsed_result.get('job_match_summary', {}).get('overall_match_percentage', 0)
        
        if 'recommendation' not in parsed_result:
            parsed_result['recommendation'] = parsed_result.get('job_match_summary', {}).get('recommendation', 'POOR_MATCH')
        
        # Ensure candidate_info exists
        if 'candidate_info' not in parsed_result:
            parsed_result['candidate_info'] = {
                'name': 'Unknown',
                'email': '',
                'phone': '',
                'location': ''
            }
        
        return parsed_result
    

    
    def get_security_events(self) -> List[Dict[str, Any]]:
        """Get recent security events"""
        return self.security_events.copy()
    
    def get_service_status(self) -> Dict[str, Any]:
        """Get service status information"""
        return {
            'status': 'healthy',
            'region': self.region,
            'model_id': self.model_id,
            'recent_requests': len(self.request_history),
            'security_events': len(self.security_events),
            'timestamp': datetime.now().isoformat()
        }