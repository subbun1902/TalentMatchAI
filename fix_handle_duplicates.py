import re

# Read the file
with open('app_simple.py.backup', 'r', encoding='utf-8') as f:
    content = f.read()

# Find and fix the incomplete handle_duplicate_candidates function
# The function is incomplete after line "name = result.get('candidate_name', '').strip().lower() if result.get('candidate_name') else ''"
# We need to complete the loop and add the return statement

incomplete_section = '''    # Add any results that weren't grouped (no name or email)
    for result in results:
        name = result.get('candidate_name', '').strip().lower() if result.get('candidate_name') else ''
    """Get interview questions"""'''

complete_section = '''    # Add any results that weren't grouped (no name or email)
    for result in results:
        name = result.get('candidate_name', '').strip().lower() if result.get('candidate_name') else ''
        email = result.get('email', '').strip().lower() if result.get('email') else ''
        
        # Skip if already processed
        if not name and not email:
            processed_results.append(result)
    
    return processed_results

@app.route('/api/interview/questions', methods=['GET'])
def get_interview_questions():
    """Get interview questions"""'''

content = content.replace(incomplete_section, complete_section)

# Write the fixed content
with open('app_simple.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed handle_duplicate_candidates function!")
