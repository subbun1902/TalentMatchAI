#!/usr/bin/env python3
"""
Simple Resume Analyzer - Clean Implementation
No complex session management, just straightforward file upload and analysis
"""

import os
import sys
import logging
from datetime import datetime
from flask import Flask, request, jsonify, render_template
from werkzeug.utils import secure_filename
import tempfile
import shutil

# Set UTF-8 encoding for Windows console
if sys.platform.startswith('win'):
    try:
        # Try to set console to UTF-8
        os.system('chcp 65001 > nul')
    except:
        pass

# Add current directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Configure logging with UTF-8 encoding support
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

# Initialize Flask app
app = Flask(__name__)

# Configure Flask for larger file uploads (for videos)
app.config['MAX_CONTENT_LENGTH'] = 100 * 1024 * 1024  # 100MB max file size

# Configure logger
logger = logging.getLogger(__name__)

# Global storage for uploaded files
uploaded_files = {
    'resumes': [],
    'job_description': None
}

# Allowed file extensions
ALLOWED_RESUME_EXTENSIONS = {'pdf', 'doc', 'docx'}
ALLOWED_JOB_EXTENSIONS = {'txt', 'pdf', 'doc', 'docx'}

def allowed_file(filename, allowed_extensions):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in allowed_extensions

def extract_text_from_file(file_path, filename):
    try:
        file_ext = os.path.splitext(filename)[1].lower()
        
        if file_ext == '.pdf':
            try:
                import PyPDF2
                with open(file_path, 'rb') as f:
                    reader = PyPDF2.PdfReader(f)
                    text = ""
                    for page in reader.pages:
                        text += page.extract_text() + "\n"
                    return text.strip()
            except Exception as e:
                logger.warning(f"PDF extraction failed: {e}")
                return f"[PDF file: {filename} - text extraction failed]"
        
        elif file_ext in ['.doc', '.docx']:
            try:
                from docx import Document
                doc = Document(file_path)
                text = ""
                for paragraph in doc.paragraphs:
                    text += paragraph.text + "\n"
                return text.strip()
            except Exception as e:
                logger.warning(f"Word document extraction failed: {e}")
                return f"[Word document: {filename} - text extraction failed]"
        
        else:
            return f"[Unsupported file type: {filename}]"
            
    except Exception as e:
        logger.error(f"Text extraction error for {filename}: {e}")
        return f"[Error extracting text from: {filename}]"

@app.route('/')
def index():
    """Main page"""
    return render_template('simple_index.html')

@app.route('/api/status')
def get_status():
    """Get current upload status"""
    # Log current state for debugging
    logger.info(f"Status check - Resumes: {len(uploaded_files['resumes'])}, Job Description: {uploaded_files['job_description'] is not None}")
    if uploaded_files['resumes']:
        logger.info(f"Resume filenames: {[r['filename'] for r in uploaded_files['resumes']]}")
    
    return jsonify({
        'success': True,
        'resume_count': len(uploaded_files['resumes']),
        'has_job_description': uploaded_files['job_description'] is not None,
        'can_analyze': len(uploaded_files['resumes']) > 0 and uploaded_files['job_description'] is not None,
        'resumes': [{'filename': r['filename'], 'upload_time': r['upload_time']} for r in uploaded_files['resumes']],
        'job_description': uploaded_files['job_description']['filename'] if uploaded_files['job_description'] else None
    })

@app.route('/upload/resumes', methods=['POST'])
def upload_resumes():
    """Upload resume files"""
    try:
        if 'files' not in request.files:
            return jsonify({'success': False, 'error': 'No files provided'}), 400
        
        files = request.files.getlist('files')
        if not files or all(f.filename == '' for f in files):
            return jsonify({'success': False, 'error': 'No files selected'}), 400
        
        processed_files = []
        errors = []
        
        for file in files:
            if file.filename == '':
                continue
            
            # Validate file type
            if not allowed_file(file.filename, ALLOWED_RESUME_EXTENSIONS):
                errors.append(f"{file.filename}: Invalid file type. Allowed: PDF, DOC, DOCX")
                continue
            
            # Check for duplicate filename
            secure_name = secure_filename(file.filename)
            existing_resume = next((r for r in uploaded_files['resumes'] if r['filename'] == secure_name), None)
            
            if existing_resume:
                errors.append(f"{file.filename}: File already uploaded. Use 'Clear All' to remove duplicates.")
                continue
            
            try:
                # Save file temporarily
                temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(file.filename)[1])
                temp_file_path = temp_file.name
                temp_file.close()  # Close file handle before saving
                
                file.save(temp_file_path)
                
                # Extract text
                text_content = extract_text_from_file(temp_file_path, file.filename)
                
                # Get file size
                file_size = os.path.getsize(temp_file_path)
                
                # Store file info
                resume_info = {
                    'filename': secure_name,
                    'text': text_content,
                    'upload_time': datetime.now().isoformat(),
                    'file_size': file_size
                }
                
                uploaded_files['resumes'].append(resume_info)
                processed_files.append(resume_info)
                
                # Clean up temp file
                try:
                    os.unlink(temp_file_path)
                except:
                    pass  # Ignore cleanup errors
                    
                logger.info(f"Resume uploaded successfully: {file.filename}")
                    
            except Exception as e:
                errors.append(f"{file.filename}: Upload failed - {str(e)}")
                logger.error(f"Resume upload error for {file.filename}: {e}")
        
        return jsonify({
            'success': True,
            'message': f'Uploaded {len(processed_files)} resume(s) successfully',
            'processed_files': [{'filename': f['filename'], 'size': f['file_size']} for f in processed_files],
            'errors': errors,
            'total_resumes': len(uploaded_files['resumes'])
        })
        
    except Exception as e:
        logger.error(f"Resume upload error: {e}")
        return jsonify({'success': False, 'error': f'Upload failed: {str(e)}'}), 500

@app.route('/upload/job-description', methods=['POST'])
def upload_job_description():
    """Upload job description file"""
    try:
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': 'No file provided'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'success': False, 'error': 'No file selected'}), 400
        
        # Validate file type
        if not allowed_file(file.filename, ALLOWED_JOB_EXTENSIONS):
            return jsonify({
                'success': False, 
                'error': f'Invalid file type. Allowed: TXT, PDF, DOC, DOCX'
            }), 400
        
        try:
            # Save file temporarily
            temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(file.filename)[1])
            temp_file_path = temp_file.name
            temp_file.close()  # Close file handle before saving
            
            file.save(temp_file_path)
            
            # Extract text
            text_content = extract_text_from_file(temp_file_path, file.filename)
            
            # Get file size
            file_size = os.path.getsize(temp_file_path)
            
            # Store job description
            uploaded_files['job_description'] = {
                'filename': secure_filename(file.filename),
                'text': text_content,
                'upload_time': datetime.now().isoformat(),
                'file_size': file_size
            }
            
            # Clean up temp file
            try:
                os.unlink(temp_file_path)
            except:
                pass  # Ignore cleanup errors
            
            logger.info(f"Job description uploaded successfully: {file.filename}")
            
            return jsonify({
                'success': True,
                'message': 'Job description uploaded successfully',
                'filename': file.filename,
                'file_size': uploaded_files['job_description']['file_size']
            })
                
        except Exception as e:
            logger.error(f"Job description processing error: {e}")
            return jsonify({'success': False, 'error': f'File processing failed: {str(e)}'}), 500
            
    except Exception as e:
        logger.error(f"Job description upload error: {e}")
        return jsonify({'success': False, 'error': f'Upload failed: {str(e)}'}), 500

@app.route('/analyze', methods=['POST'])
def analyze():
    """Start analysis of resumes against job description using AWS Bedrock"""
    try:
        # Check if we have both resumes and job description
        if len(uploaded_files['resumes']) == 0:
            return jsonify({'success': False, 'error': 'No resumes uploaded'}), 400
        
        if uploaded_files['job_description'] is None:
            return jsonify({'success': False, 'error': 'No job description uploaded'}), 400
        
        # Import AWS service
        try:
            import sys
            import os
            
            # Add services directory to path
            services_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'services')
            if services_path not in sys.path:
                sys.path.insert(0, services_path)
            
            # Import the AWS service
            from services.aws_security_service import AWSSecurityService
            
            aws_service = AWSSecurityService()
            logger.info("AWS Bedrock service initialized for analysis")
            
        except Exception as e:
            logger.error(f"Failed to initialize AWS service: {e}")
            return jsonify({
                'success': False, 
                'error': f'AWS service initialization failed: {str(e)}'
            }), 500
        
        # Perform AWS Bedrock analysis
        results = []
        job_desc_text = uploaded_files['job_description']['text']
        
        for resume in uploaded_files['resumes']:
            resume_text = resume['text']
            
            logger.info(f"Analyzing resume: {resume['filename']} with AWS Bedrock")
            
            # Call AWS Bedrock for analysis
            aws_result = aws_service.analyze_resume_with_bedrock(
                resume_text=resume_text,
                job_description=job_desc_text,
                analysis_type="comprehensive",
                filename=resume['filename']
            )
            
            if aws_result['success']:
                analysis_data = aws_result['analysis']
                
                # Check if analysis data contains parsing errors
                if analysis_data.get('parsing_error'):
                    # Handle parsing errors - don't create fallback data
                    analysis_result = {
                        'filename': resume['filename'],
                        'error': True,
                        'error_type': analysis_data.get('error_type', 'PARSING_ERROR'),
                        'error_message': analysis_data.get('error_message', 'Failed to parse AWS Bedrock response'),
                        'raw_response_preview': analysis_data.get('raw_response_preview', ''),
                        'analysis_timestamp': aws_result.get('timestamp')
                    }
                    logger.error(f"AWS parsing failed for {resume['filename']}: {analysis_data.get('error_message')}")
                else:
                    # Structure the result for our UI with the simpler data structure
                    candidate_info = analysis_data.get('candidate_info', {})
                    skills_analysis = analysis_data.get('skills_analysis', {})
                    experience_analysis = analysis_data.get('experience_analysis', {})
                    education_analysis = analysis_data.get('education_analysis', {})
                
                    analysis_result = {
                        'filename': resume['filename'],
                        # Candidate Information
                        'candidate_name': candidate_info.get('name'),
                        'current_designation': candidate_info.get('current_designation'),
                        'current_company': candidate_info.get('current_company'),
                        'email': candidate_info.get('email'),
                        'phone': candidate_info.get('phone'),
                        'location': candidate_info.get('location'),
                        
                        # Match Results
                        'match_percentage': analysis_data.get('overall_match_percentage', 0),
                        'recommendation': analysis_data.get('recommendation', 'UNKNOWN'),
                        
                        # Skills Analysis
                        'skills_analysis': skills_analysis,
                        
                        # Experience Analysis
                        'experience_analysis': experience_analysis,
                        'years_of_experience': experience_analysis.get('years_of_experience', 0),
                        
                        # Education Analysis
                        'education_analysis': education_analysis,
                        
                        # Core Fields
                        'strengths': analysis_data.get('strengths', []),
                        'weaknesses': analysis_data.get('areas_for_improvement', []),
                        'areas_for_improvement': analysis_data.get('areas_for_improvement', []),
                        'key_highlights': analysis_data.get('key_highlights', []),
                        'interview_questions': analysis_data.get('interview_questions', []),
                        'summary': analysis_data.get('summary', 'No summary available'),
                        'model_used': aws_result.get('model_used', 'Unknown'),
                        'analysis_timestamp': aws_result.get('timestamp')
                    }
                    
                    logger.info(f"AWS analysis completed for {resume['filename']}: {analysis_result['match_percentage']}% match")
                
            else:
                # AWS Bedrock failed - show error instead of fallback analysis
                logger.error(f"AWS Bedrock failed for {resume['filename']}: {aws_result.get('error')}")
                
                analysis_result = {
                    'filename': resume['filename'],
                    'error': True,
                    'error_type': aws_result.get('error_type', 'BEDROCK_ERROR'),
                    'error_message': aws_result.get('error', 'AWS Bedrock analysis failed'),
                    'duration': aws_result.get('duration', 0),
                    'analysis_timestamp': aws_result.get('timestamp')
                }
            
            results.append(analysis_result)
        
        # Simple duplicate detection and handling
        results = handle_duplicate_candidates(results)
        
        logger.info(f"Analysis completed for {len(results)} resumes using AWS Bedrock")
        
        return jsonify({
            'success': True,
            'message': 'Analysis completed successfully using AWS Bedrock',
            'job_description': uploaded_files['job_description']['filename'],
            'total_resumes': len(results),
            'results': results,
            'analysis_time': datetime.now().isoformat(),
            'analysis_method': 'AWS Bedrock Claude'
        })
        
    except Exception as e:
        logger.error(f"Analysis error: {e}")
        return jsonify({'success': False, 'error': f'Analysis failed: {str(e)}'}), 500

@app.route('/clear', methods=['POST'])
def clear_uploads():
    """Clear all uploaded files"""
    try:
        # Log current state before clearing
        logger.info(f"Before clear - Resumes: {len(uploaded_files['resumes'])}, Job Description: {uploaded_files['job_description'] is not None}")
        
        uploaded_files['resumes'] = []
        uploaded_files['job_description'] = None
        
        # Log state after clearing
        logger.info(f"After clear - Resumes: {len(uploaded_files['resumes'])}, Job Description: {uploaded_files['job_description'] is not None}")
        logger.info("All uploads cleared successfully")
        
        return jsonify({
            'success': True,
            'message': 'All uploads cleared successfully',
            'resume_count': len(uploaded_files['resumes']),
            'has_job_description': uploaded_files['job_description'] is not None
        })
        
    except Exception as e:
        logger.error(f"Clear error: {e}")
        return jsonify({'success': False, 'error': f'Clear failed: {str(e)}'}), 500



def handle_duplicate_candidates(results):
    """
    Simple duplicate detection and handling based on candidate name and email.
    When duplicates are found, keeps the one with the highest match percentage
    and marks others as duplicates.
    """
    if not results:
        return results
    
    # Group candidates by name and email
    candidate_groups = {}
    
    for result in results:
        # Create a key based on candidate name and email
        name = result.get('candidate_name', '').strip().lower() if result.get('candidate_name') else ''
        email = result.get('email', '').strip().lower() if result.get('email') else ''
        
        # Skip if no name or email available
        if not name and not email:
            continue
            
        # Create grouping key - use both name and email if available, otherwise just one
        if name and email:
            key = f"{name}|{email}"
        elif name:
            key = f"name:{name}"
        elif email:
            key = f"email:{email}"
        else:
            continue
            
        if key not in candidate_groups:
            candidate_groups[key] = []
        candidate_groups[key].append(result)
    
    # Process duplicates
    processed_results = []
    duplicate_count = 0
    
    for key, group in candidate_groups.items():
        if len(group) == 1:
            # No duplicates, add as-is
            processed_results.append(group[0])
        else:
            # Handle duplicates - keep the one with highest match percentage
            group.sort(key=lambda x: x.get('match_percentage', 0), reverse=True)
            best_candidate = group[0]
            
            # Mark the best candidate with duplicate info
            best_candidate['duplicate_info'] = {
                'is_best_version': True,
                'total_versions': len(group),
                'other_filenames': [r['filename'] for r in group[1:]],
                'other_scores': [r.get('match_percentage', 0) for r in group[1:]]
            }
            
            # Add duplicate warning to summary
            original_summary = best_candidate.get('summary', '')
            best_candidate['summary'] = f"DUPLICATE DETECTED: Found {len(group)} versions of this candidate. This is the best scoring version. {original_summary}"
            
            processed_results.append(best_candidate)
            duplicate_count += len(group) - 1
    
    # Add any results that weren't grouped (no name or email)
    for result in results:
        name = result.get('candidate_name', '').strip().lower() if result.get('candidate_name') else ''
        email = result.get('email', '').strip().lower() if result.get('email') else ''
        
        # Skip if already processed
        if not name and not email:
            processed_results.append(result)
    
    return processed_results

@app.route('/api/interview/questions', methods=['GET'])
def get_interview_questions():
    """Get interview questions"""
    try:
        # Check if we have resumes and job description
        if not uploaded_files['resumes'] or not uploaded_files['job_description']:
            return jsonify({
                'success': False,
                'error': 'Please upload a resume and job description first'
            }), 400
            
        # Use the first resume for now
        resume_text = uploaded_files['resumes'][0]['text']
        job_desc_text = uploaded_files['job_description']['text']
        
        # Import AWS service
        try:
            import sys
            import os
            
            # Add services directory to path
            services_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'services')
            if services_path not in sys.path:
                sys.path.insert(0, services_path)
            
            # Import the AWS service
            from services.aws_security_service import AWSSecurityService
            
            aws_service = AWSSecurityService()
            
            # Generate questions
            # TODO: Implement generate_interview_questions method in AWSSecurityService
            result = {'success': True, 'questions': [], 'message': 'Interview questions feature not yet implemented'}
            
            return jsonify(result)
            
        except Exception as e:
            logger.error(f"Failed to generate questions: {e}")
            return jsonify({
                'success': False, 
                'error': f'Question generation failed: {str(e)}'
            }), 500
            
    except Exception as e:
        logger.error(f"Interview API error: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/interview/submit', methods=['POST'])
def submit_interview_video():
    """Submit interview video recording"""
    try:
        # Check if video file is present
        if 'video' not in request.files:
            return jsonify({'success': False, 'error': 'No video file provided'}), 400
        
        video_file = request.files['video']
        if video_file.filename == '':
            return jsonify({'success': False, 'error': 'No video file selected'}), 400
        
        # Get additional metadata
        question_id = request.form.get('question_id', 'unknown')
        candidate_name = request.form.get('candidate_name', 'anonymous')
        
        # Create videos directory if it doesn't exist
        videos_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'videos')
        os.makedirs(videos_dir, exist_ok=True)
        
        # Generate unique filename
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        safe_candidate_name = secure_filename(candidate_name.replace(' ', '_'))
        filename = f"interview_{safe_candidate_name}_q{question_id}_{timestamp}.webm"
        filepath = os.path.join(videos_dir, filename)
        
        # Save video file
        video_file.save(filepath)
        file_size = os.path.getsize(filepath)
        
        logger.info(f"Interview video saved: {filename} ({file_size} bytes)")
        
        # Store video metadata (you could save this to a database)
        video_metadata = {
            'filename': filename,
            'filepath': filepath,
            'question_id': question_id,
            'candidate_name': candidate_name,
            'upload_time': datetime.now().isoformat(),
            'file_size': file_size
        }
        
        return jsonify({
            'success': True,
            'message': 'Video uploaded successfully',
            'video_id': filename,
            'file_size': file_size
        })
        
    except Exception as e:
        logger.error(f"Video upload error: {e}")
        return jsonify({'success': False, 'error': f'Upload failed: {str(e)}'}), 500

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='TalentMatch AI - Resume Analysis Platform')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to (default: 0.0.0.0)')
    parser.add_argument('--port', type=int, default=5000, help='Port to bind to (default: 5000)')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    
    args = parser.parse_args()
    
    print("Starting TalentMatch AI...")
    print(f"Server will be available at: http://{args.host}:{args.port}")
    print("Upload resumes and job descriptions to get AI-powered matching analysis")
    
    app.run(debug=args.debug, host=args.host, port=args.port)

if __name__ == '__main__':
    main()