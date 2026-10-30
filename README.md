# TalentMatch AI

An intelligent resume analysis platform powered by AWS Bedrock AI that helps recruiters and hiring managers efficiently match candidates to job requirements with precision and insight.

## 🚀 Key Features

### 📄 Multi-Format Document Support
- **Resume Upload**: PDF and Word document formats
- **Job Descriptions**: PDF and Word document support
- **Batch Processing**: ZIP file uploads for multiple resumes
- **File Validation**: Automatic format detection and validation

### 🤖 AI-Powered Analysis
- **AWS Bedrock Integration**: Claude 3 Sonnet model with reliable connection management
- **Matching Algorithm**: Sophisticated resume-job description matching
- **Skills Assessment**: Comprehensive skills gap analysis
- **Percentage Scoring**: Quantified candidate fit ratings
- **Reliability Features**: Connection pooling, intelligent retry, and error handling

### 📊 Interactive Dashboard
- **Results Visualization**: Clean, intuitive analysis display
- **Detailed Insights**: Skills breakdown and recommendations
- **Batch Results**: Multi-resume comparison views
- **Export Options**: Analysis results in multiple formats

### 🎯 Target Users
- Recruiters and HR professionals
- Hiring managers and talent acquisition teams
- Small to medium businesses streamlining hiring processes

## 🛠️ Quick Start

### Prerequisites
- **Python 3.8+**: Core runtime environment
- **AWS Account**: With Bedrock service access enabled
- **AWS Credentials**: Configured via CLI, environment variables, or IAM roles

### Installation

1. **Clone and Navigate**
   ```bash
   git clone <repository-url>
   cd talentmatch-ai
   ```

2. **Create Virtual Environment**
   ```bash
   python -m venv venv
   ```

3. **Activate Environment**
   ```bash
   # Windows
   venv\Scripts\activate
   
   # macOS/Linux
   source venv/bin/activate
   ```

4. **Install Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

5. **Configure Environment**
   ```bash
   cp .env.example .env
   ```
   Edit `.env` with your AWS credentials:
   ```env
   AWS_ACCESS_KEY_ID=your_access_key
   AWS_SECRET_ACCESS_KEY=your_secret_key
   AWS_DEFAULT_REGION=us-east-1
   FLASK_ENV=development
   ```

6. **Launch Application**
   ```bash
   python app.py
   ```
   
   🌐 Access at: `http://localhost:5000`

### AWS Bedrock Setup
Ensure your AWS account has access to Claude 3 Sonnet model in AWS Bedrock. You may need to request model access through the AWS Console.

### Reliability Configuration
The application includes advanced reliability features for AWS Bedrock integration:

```env
# Connection Management (optional - defaults provided)
BEDROCK_MAX_CONNECTIONS=3
BEDROCK_REQUEST_TIMEOUT=60
BEDROCK_QUEUE_TIMEOUT=10

# Retry Strategy (optional - defaults provided)
BEDROCK_MAX_RETRIES=5
BEDROCK_BASE_DELAY=2.0
BEDROCK_MAX_DELAY=60.0

# Performance Monitoring (optional - defaults provided)
PERFORMANCE_WARNING_THRESHOLD=30
PERFORMANCE_MAX_THRESHOLD=60
ENABLE_PERFORMANCE_LOGGING=true
```

## 📁 Project Architecture

```
talentmatch-ai/
├── app.py                    # 🚀 Main Flask application entry point
├── config.py                # ⚙️ Environment-based configuration
├── requirements.txt         # 📦 Python dependencies
├── .env.example            # 🔧 Environment variables template
├── models/                 # 📊 Data models and validation logic
├── services/               # 🔧 Business logic and integrations
│   └── file_processor.py   # 📄 Document processing service
├── templates/              # 🎨 Jinja2 HTML templates
│   ├── base.html          # 🏗️ Base template with common layout
│   ├── index.html         # 📤 Main upload interface
│   └── dashboard.html     # 📈 Analysis results display
├── static/                 # 🎯 Frontend assets
│   ├── css/               # 🎨 Stylesheets
│   └── js/                # ⚡ JavaScript files
└── uploads/                # 📁 Temporary file storage (gitignored)
```

### 🏗️ Architecture Patterns
- **Modular Design**: Clear separation between models, services, and presentation
- **Configuration Management**: Environment-based configs for dev/prod/test
- **Service Layer**: Business logic abstraction for AI integration
- **Template Inheritance**: Consistent UI with Jinja2 base templates

## 🔧 Development

### Technology Stack
- **Backend**: Flask 2.3.3, Python 3.8+
- **AI Service**: AWS Bedrock (Claude 3 Sonnet) with reliability features
- **Document Processing**: PyPDF2, pdfplumber, python-docx
- **Testing**: pytest with coverage analysis
- **Cloud**: boto3 for AWS integration
- **Reliability**: Connection pooling, async support, intelligent retry strategies

### Development Commands
```bash
# Run development server
python app.py

# Run tests with coverage
pytest --cov=.

# Install new dependency
pip install package-name
pip freeze > requirements.txt

# Format code (if using black)
black .
```

### Code Organization
- **Models**: Data structures, validation, business entities
- **Services**: External integrations, file processing, AI analysis
- **Templates**: UI components with base template inheritance
- **Static**: Organized frontend assets (CSS, JS)

### Contributing
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📈 Usage Examples

### Single Resume Analysis
1. Upload a resume (PDF/Word) and job description
2. Click "Analyze" to process with AI
3. View matching percentage and skills analysis
4. Review recommendations and gaps

### Batch Processing
1. Create ZIP file with multiple resumes
2. Upload ZIP along with job description
3. Process all resumes simultaneously
4. Compare candidates in dashboard view

## 🔧 Troubleshooting

### Common Issues

**AWS Bedrock Connection Errors**
- The application includes automatic retry and connection pooling
- If you see "Too many connections" errors, the system will automatically queue requests
- Check your AWS credentials and Bedrock model access permissions

**Performance Issues**
- Processing times over 30 seconds will show warnings
- The system automatically optimizes connection reuse
- Monitor logs for performance metrics and recommendations

**Configuration Issues**
- Verify your `.env` file contains valid AWS credentials
- Ensure AWS Bedrock has access to Claude 3 Sonnet model
- Check AWS region settings match your account setup

## 🤝 Support & Community

- **Issues**: Report bugs or request features via GitHub Issues
- **Documentation**: Comprehensive guides in `/docs` directory
- **Community**: Join discussions in GitHub Discussions

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**TalentMatch AI** - Transforming talent acquisition with intelligent resume analysis 🎯