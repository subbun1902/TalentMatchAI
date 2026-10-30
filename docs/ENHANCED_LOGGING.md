# Enhanced Logging and Audit Capabilities

This document describes the comprehensive logging and audit system implemented for the Resume Analyzer's scoring functionality.

## Overview

The enhanced logging system provides detailed tracking of all scoring decisions, validations, adjustments, and performance metrics. It includes specialized loggers, audit trails, metrics collection, and comprehensive reporting capabilities.

## Components

### 1. Specialized Loggers

The system uses multiple specialized loggers for different types of information:

- **`scoring`**: Main scoring decisions and high-level events
- **`scoring.audit`**: Detailed audit trail in JSON format
- **`scoring.metrics`**: Performance and accuracy metrics
- **`scoring.debug`**: Detailed debugging information

### 2. Log Files

All logs are stored in the `logs/` directory with automatic rotation:

- `logs/scoring.log` - Main scoring events and decisions
- `logs/scoring_audit.log` - Structured audit trail (JSON format)
- `logs/scoring_metrics.log` - Performance and accuracy metrics
- `logs/scoring_debug.log` - Detailed debugging information
- `logs/app.log` - General application logs

### 3. Audit Trail

The `ScoringAuditTrail` class provides comprehensive tracking of:

- **Scoring Decisions**: Complete scoring breakdown with component scores
- **Validation Results**: Score validation outcomes and adjustments
- **Anomaly Detection**: Detected scoring anomalies and recommended actions

### 4. Metrics Collection

The `ScoringMetricsCollector` class tracks:

- **Performance Metrics**: Response times, memory usage, token consumption
- **Accuracy Metrics**: Validation pass rates, confidence levels, adjustment rates

## Key Features

### Detailed Scoring Decision Logging

Every scoring decision is logged with complete details:

```json
{
  "timestamp": "2025-10-21T13:38:30.682940",
  "analysis_id": "abc123",
  "event_type": "SCORING_DECISION",
  "scoring_data": {
    "overall_score": 75,
    "component_scores": {
      "skills": 80,
      "experience": 70,
      "education": 65
    },
    "recommendation": "GOOD_MATCH",
    "model_used": "claude-3-sonnet",
    "analysis_type": "comprehensive"
  },
  "candidate_info": {
    "filename": "resume.pdf",
    "candidate_name": "John Doe"
  }
}
```

### Validation Result Tracking

All score validations are tracked with adjustment details:

```json
{
  "timestamp": "2025-10-21T13:38:30.683940",
  "analysis_id": "abc123",
  "event_type": "VALIDATION_RESULT",
  "validation_data": {
    "validation_passed": false,
    "confidence_level": "MEDIUM",
    "adjustments_made": ["Score variance detected: AI=75%, Calculated=68%"],
    "original_score": 75,
    "final_score": 68,
    "score_variance": 7
  }
}
```

### Performance Monitoring

Performance metrics are collected for every analysis:

```json
{
  "timestamp": "2025-10-21T13:38:30.683791",
  "analysis_id": "abc123",
  "performance_data": {
    "total_time_ms": 3500,
    "bedrock_time_ms": 2800,
    "validation_time_ms": 500,
    "anomaly_detection_time_ms": 200,
    "memory_usage_mb": 128.5,
    "tokens_used": 1250
  }
}
```

### Anomaly Detection Logging

Scoring anomalies are logged with detailed analysis:

```json
{
  "timestamp": "2025-10-21T13:38:30.684940",
  "analysis_id": "abc123",
  "event_type": "ANOMALY_DETECTION",
  "anomaly_data": {
    "anomalies_detected": [
      {
        "type": "IDENTICAL_SCORES",
        "severity": "HIGH",
        "description": "3 candidates received identical score of 72%"
      }
    ],
    "reanalysis_recommended": true,
    "priority": "HIGH"
  }
}
```

## API Endpoints

### Scoring Report

Get comprehensive scoring reports:

```
GET /api/scoring/report?hours=24
```

Returns detailed analysis of scoring performance, accuracy, and health indicators.

### Health Check

Get current scoring system health:

```
GET /api/scoring/health
```

Returns system health status and recommendations.

## Usage Examples

### Generating Reports

```python
from services.scoring_logger import generate_comprehensive_scoring_report

# Generate 24-hour report
report = generate_comprehensive_scoring_report(24)
print(f"Health Status: {report['overall_health']['status']}")
print(f"Total Analyses: {report['audit_summary']['totals']['analyses']}")
```

### Accessing Audit Trail

```python
from services.scoring_logger import get_audit_trail

audit_trail = get_audit_trail()
summary = audit_trail.get_audit_summary(24)
print(f"Validation Pass Rate: {summary['validation_stats']['pass_rate']:.1f}%")
```

### Performance Metrics

```python
from services.scoring_logger import get_metrics_collector

metrics = get_metrics_collector()
performance = metrics.get_performance_summary(24)
print(f"Average Response Time: {performance['performance_indicators']['average_response_time_ms']:.0f}ms")
```

## Troubleshooting

### Log Troubleshooting Information

The system automatically logs troubleshooting information for issues:

```python
from services.scoring_logger import log_troubleshooting_info

log_troubleshooting_info(
    analysis_id="abc123",
    issue_type="VALIDATION_FAILURE",
    details={
        "original_score": 85,
        "expected_score": 72,
        "variance": 13
    }
)
```

### Common Issues and Solutions

1. **High Validation Failure Rate**
   - Check component score calculations
   - Review AI prompt instructions
   - Verify skills penalty rules

2. **Performance Issues**
   - Monitor AWS Bedrock response times
   - Check system resources
   - Review request payload sizes

3. **Score Clustering**
   - Enhance scoring granularity
   - Review AI model parameters
   - Check for identical candidate profiles

## Configuration

### Log Retention

- Maximum log file size: 50MB
- Backup count: 5 files
- Retention period: 30 days

### Memory Management

- Audit entries: 10,000 recent entries in memory
- Performance metrics: 1,000 recent entries
- Accuracy metrics: 1,000 recent entries

## Integration

The enhanced logging is automatically integrated into:

- AWS Bedrock analysis pipeline
- Score validation process
- Anomaly detection system
- Performance monitoring

All existing functionality continues to work with enhanced logging running transparently in the background.

## Benefits

1. **Complete Audit Trail**: Every scoring decision is tracked and auditable
2. **Performance Monitoring**: Real-time performance metrics and optimization insights
3. **Quality Assurance**: Validation tracking and accuracy monitoring
4. **Troubleshooting**: Detailed debugging information for issue resolution
5. **Reporting**: Comprehensive reports for monitoring and improvement
6. **Anomaly Detection**: Automatic detection of scoring issues and patterns

## Requirements

The enhanced logging system requires:

- Python 3.8+
- psutil (for system metrics)
- Standard logging library
- JSON support

All dependencies are included in the project's requirements.txt file.