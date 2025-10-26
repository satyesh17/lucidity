```mermaid
graph TB
    subgraph "Management Account (741752824171)"
        A[Ansible EC2 Instance] --> B[IAM Management Role]
        B --> C[DynamoDB Inventory]
        B --> D[S3 Config Bucket]
        B --> E[CloudWatch Dashboard]
    end
    
    subgraph "Dev Account (193779369106)"
        F[Cross-Account IAM Role] --> G[EC2 Linux Instances]
        F --> H[EC2 Windows Instances]
        G --> I[CloudWatch Agent]
        H --> J[CloudWatch Agent]
    end
    
    A -->|STS AssumeRole| F
    A -->|SSM Session Manager| G
    A -->|SSM Session Manager| H
    I -->|Metrics| E
    J -->|Metrics| E
    
    style A fill:#e1f5fe
    style E fill:#f3e5f5
    style C fill:#e8f5e8
