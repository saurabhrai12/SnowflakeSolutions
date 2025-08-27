# Nudge Generation Engine - Low Level Solution Design

## 1. Executive Summary

The Nudge Generation Engine is a hybrid real-time and batch processing system that evaluates business rules against events from multiple data sources to generate personalized nudges. The system processes real-time events from PostgreSQL ODS, near real-time and batch events from Snowflake Data Lake, and distributes nudges through Amazon MSK and API channels.

## 2. Architecture Overview

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Data Sources Layer                          │
├───────────────┬──────────────────┬──────────────────────────────────┤
│  PostgreSQL   │   Snowflake      │      Other Sources               │
│     ODS       │   Data Lake      │   (Future Extension)             │
└───────┬───────┴────────┬─────────┴──────────────────────────────────┘
        │                │                      │
        ▼                ▼                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Data Fabric Layer (Optional)                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │         Unified Data Access & Abstraction Service            │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Event Processing Layer                            │
├─────────────────────────────┬───────────────────────────────────────┤
│   Real-Time Stream          │      Batch Processing                 │
│   Processing Engine          │         Engine                        │
└─────────────────────────────┴───────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Rules Evaluation Engine                           │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │               Business Rules Processor                        │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Distribution Layer                                │
├────────────────────┬────────────────────┬───────────────────────────┤
│    Amazon MSK      │    Snowflake       │      API Gateway          │
│    (Streaming)     │   (Persistence)    │    (REST/GraphQL)         │
└────────────────────┴────────────────────┴───────────────────────────┘
```

## 3. Component Details

### 3.1 Data Sources Layer

#### PostgreSQL ODS (Operational Data Store)
- **Purpose**: Real-time transactional events
- **Technology**: PostgreSQL 14+
- **Data Capture Method**: 
  - CDC (Change Data Capture) using logical replication
  - Debezium connector for Kafka Connect
- **Event Types**: User actions, transactions, system events
- **Latency**: < 100ms

#### Snowflake Data Lake
- **Purpose**: Near real-time and batch analytical events
- **Technology**: Snowflake Enterprise Edition
- **Data Access Method**:
  - Snowpipe for near real-time ingestion
  - Scheduled batch jobs for historical processing
- **Event Types**: Aggregated metrics, historical patterns, enriched events
- **Latency**: 1-5 minutes (near real-time), hourly/daily (batch)

### 3.2 Data Fabric Layer (Optional)

#### Unified Data Access Service
```yaml
Components:
  - Data Catalog Service:
      - Schema registry
      - Data lineage tracking
      - Metadata management
  
  - Data Router:
      - Intelligent query routing
      - Source selection based on freshness/cost
      - Caching layer (Redis/Hazelcast)
  
  - Data Transformation Engine:
      - Schema harmonization
      - Data quality validation
      - Format conversion (Avro, JSON, Parquet)
  
  - Access Control:
      - OAuth 2.0/SAML authentication
      - Row/column level security
      - Audit logging
```

**Technology Stack**:
- Apache Atlas or DataHub for data catalog
- Apache Kafka Connect for data integration
- Apache Flink/Spark for transformations
- Redis for caching layer

### 3.3 Event Processing Layer

#### Real-Time Stream Processing Engine
```yaml
Technology: Apache Flink / Kafka Streams
Configuration:
  - Parallelism: 10-50 based on load
  - Checkpointing: Every 60 seconds
  - State Backend: RocksDB
  - Window Types:
    - Tumbling: 5 min, 15 min
    - Sliding: 30 min with 5 min slide
    - Session: 30 min timeout

Processing Pipeline:
  1. Event Ingestion:
     - Kafka consumer groups
     - Schema validation
     - Deduplication (based on event_id)
  
  2. Event Enrichment:
     - User profile lookup
     - Historical context addition
     - Feature extraction
  
  3. Event Aggregation:
     - Count aggregations
     - Sum/Avg calculations
     - Pattern detection
```

#### Batch Processing Engine
```yaml
Technology: Apache Spark / Snowflake Tasks
Configuration:
  - Cluster Size: Auto-scaling (2-10 nodes)
  - Processing Schedule: Hourly, Daily, Weekly
  - Resource Management: YARN/Kubernetes

Processing Pipeline:
  1. Data Extraction:
     - Incremental pulls using watermarks
     - Full snapshot for reconciliation
  
  2. Complex Analytics:
     - ML model scoring
     - Cohort analysis
     - Trend detection
  
  3. Result Publishing:
     - Write to staging tables
     - Trigger downstream processes
```

### 3.4 Rules Evaluation Engine

#### Rules Data Model (Snowflake)
```sql
-- Rules Master Table
CREATE TABLE nudge_rules (
    rule_id VARCHAR(50) PRIMARY KEY,
    rule_name VARCHAR(200),
    rule_category VARCHAR(50),
    rule_type VARCHAR(20), -- 'real_time', 'batch', 'hybrid'
    priority INT,
    is_active BOOLEAN,
    effective_from TIMESTAMP,
    effective_to TIMESTAMP,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Rules Conditions Table
CREATE TABLE rule_conditions (
    condition_id VARCHAR(50) PRIMARY KEY,
    rule_id VARCHAR(50) REFERENCES nudge_rules(rule_id),
    condition_type VARCHAR(30), -- 'simple', 'complex', 'ml_based'
    field_name VARCHAR(100),
    operator VARCHAR(20), -- '=', '!=', '>', '<', 'IN', 'BETWEEN', 'REGEX'
    value_type VARCHAR(20), -- 'static', 'dynamic', 'reference'
    condition_value VARCHAR(500),
    logical_operator VARCHAR(10), -- 'AND', 'OR'
    sequence_order INT
);

-- Rules Actions Table
CREATE TABLE rule_actions (
    action_id VARCHAR(50) PRIMARY KEY,
    rule_id VARCHAR(50) REFERENCES nudge_rules(rule_id),
    action_type VARCHAR(30), -- 'nudge', 'alert', 'recommendation'
    nudge_template_id VARCHAR(50),
    channel VARCHAR(30), -- 'push', 'email', 'in_app', 'sms'
    priority_score INT,
    cooldown_period_hours INT
);

-- Nudge Templates Table
CREATE TABLE nudge_templates (
    template_id VARCHAR(50) PRIMARY KEY,
    template_name VARCHAR(200),
    content_template TEXT,
    personalization_fields JSON,
    locale VARCHAR(10),
    version INT
);
```

#### Rules Processing Logic
```python
class RulesEvaluationEngine:
    def __init__(self):
        self.rule_cache = RuleCache()  # In-memory cache with TTL
        self.expression_engine = ExpressionEngine()
        
    def evaluate_event(self, event: Dict) -> List[Nudge]:
        # 1. Load applicable rules based on event type
        applicable_rules = self.rule_cache.get_rules_for_event(
            event_type=event['type'],
            timestamp=event['timestamp']
        )
        
        # 2. Evaluate each rule
        triggered_nudges = []
        for rule in applicable_rules:
            if self.evaluate_rule_conditions(rule, event):
                nudge = self.generate_nudge(rule, event)
                if self.check_nudge_eligibility(nudge, event['user_id']):
                    triggered_nudges.append(nudge)
        
        # 3. Apply priority and deduplication
        return self.prioritize_and_dedupe(triggered_nudges)
    
    def evaluate_rule_conditions(self, rule: Rule, event: Dict) -> bool:
        # Complex condition evaluation with support for:
        # - Nested conditions
        # - Time-based conditions
        # - Historical lookups
        # - ML model scoring
        pass
```

### 3.5 Nudge Generation & Distribution

#### Nudge Data Model
```python
@dataclass
class Nudge:
    nudge_id: str  # UUID
    user_id: str
    rule_id: str
    nudge_type: str
    content: Dict[str, Any]
    channels: List[str]
    priority: int
    generated_at: datetime
    expires_at: datetime
    delivery_status: Dict[str, str]  # channel -> status
    metadata: Dict[str, Any]
```

#### MSK (Managed Streaming for Kafka) Configuration
```yaml
Cluster Configuration:
  - Cluster Name: nudge-streaming-cluster
  - Kafka Version: 2.8.1
  - Instance Type: kafka.m5.large
  - Number of Brokers: 3 (multi-AZ)
  - Storage: 1000 GB per broker

Topics:
  - nudge.generated:
      Partitions: 50
      Replication Factor: 3
      Retention: 7 days
      Compression: snappy
  
  - nudge.delivered:
      Partitions: 10
      Replication Factor: 2
      Retention: 30 days
  
  - nudge.failed:
      Partitions: 5
      Replication Factor: 2
      Retention: 90 days

Producer Configuration:
  - Acks: all
  - Retries: 3
  - Batch Size: 16384
  - Linger MS: 10
  - Compression Type: snappy
```

#### Snowflake Persistence Schema
```sql
-- Nudges fact table
CREATE TABLE nudges_fact (
    nudge_id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50),
    rule_id VARCHAR(50),
    nudge_type VARCHAR(30),
    content VARIANT, -- JSON content
    channels ARRAY,
    priority INT,
    generated_at TIMESTAMP,
    expires_at TIMESTAMP,
    inserted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) CLUSTER BY (generated_at, user_id);

-- Nudge delivery tracking
CREATE TABLE nudge_delivery (
    delivery_id VARCHAR(50) PRIMARY KEY,
    nudge_id VARCHAR(50),
    channel VARCHAR(30),
    delivery_status VARCHAR(20),
    delivered_at TIMESTAMP,
    opened_at TIMESTAMP,
    clicked_at TIMESTAMP,
    error_message VARCHAR(500)
);

-- User nudge history (for deduplication)
CREATE TABLE user_nudge_history (
    user_id VARCHAR(50),
    nudge_type VARCHAR(30),
    rule_id VARCHAR(50),
    last_sent_at TIMESTAMP,
    cooldown_until TIMESTAMP,
    total_sent INT,
    PRIMARY KEY (user_id, nudge_type, rule_id)
);
```

### 3.6 API Distribution Layer

#### API Gateway Design
```yaml
Technology: AWS API Gateway / Kong / Custom FastAPI
Endpoints:
  - GET /api/v1/nudges/user/{user_id}:
      Description: Get pending nudges for user
      Cache: 60 seconds
      Rate Limit: 100 req/min per user
  
  - POST /api/v1/nudges/acknowledge:
      Description: Mark nudge as seen/acted upon
      Async Processing: Yes
  
  - GET /api/v1/nudges/history/{user_id}:
      Description: Get historical nudges
      Pagination: Required
      Default Limit: 50
  
  - POST /api/v1/nudges/feedback:
      Description: Submit user feedback on nudge

Authentication: OAuth 2.0 / API Keys
Response Format: JSON / Protocol Buffers
```

## 4. Data Flow Sequences

### 4.1 Real-Time Event Processing Flow
```
1. PostgreSQL ODS → CDC Event
2. Debezium → Kafka Connect → Event Stream
3. Stream Processor → Event Enrichment
4. Rules Engine → Evaluate Conditions
5. Nudge Generator → Create Nudge Object
6. Parallel Distribution:
   a. MSK Producer → Publish to Topic
   b. Snowflake Writer → Persist to Table
7. API Cache → Update User Nudges
```

### 4.2 Batch Processing Flow
```
1. Scheduler Trigger → Batch Job Start
2. Snowflake Query → Extract Events
3. Spark Processing → Complex Analytics
4. Rules Engine → Batch Evaluation
5. Bulk Nudge Generation
6. Batch Write → Snowflake Tables
7. MSK Producer → Bulk Publish
```

## 5. Scalability & Performance

### 5.1 Performance Targets
- **Real-time Processing**: < 500ms end-to-end latency
- **Batch Processing**: Process 100M events/hour
- **API Response Time**: p99 < 100ms
- **Rule Evaluation**: 10,000 rules/second
- **MSK Throughput**: 100,000 messages/second

### 5.2 Scaling Strategy
```yaml
Horizontal Scaling:
  - Stream Processors: Auto-scale based on lag
  - API Servers: HPA based on CPU/Memory
  - Kafka Partitions: Increase for parallelism

Vertical Scaling:
  - Snowflake: Auto-scale warehouse size
  - PostgreSQL: Read replicas for queries

Caching Strategy:
  - Rules: 5-minute TTL in Redis
  - User Nudges: 60-second TTL
  - Feature Flags: 1-minute TTL
```

## 6. Monitoring & Observability

### 6.1 Key Metrics
```yaml
Business Metrics:
  - Nudges generated per hour
  - Nudge delivery success rate
  - User engagement rate
  - Rule hit rate

Technical Metrics:
  - Event processing lag
  - Rule evaluation latency
  - API response times
  - Error rates by component
  - Kafka consumer lag
  - Snowflake query performance
```

### 6.2 Monitoring Stack
- **Metrics**: Prometheus + Grafana
- **Logging**: ELK Stack (Elasticsearch, Logstash, Kibana)
- **Tracing**: Jaeger / AWS X-Ray
- **Alerting**: PagerDuty / Opsgenie

## 7. Security & Compliance

### 7.1 Security Measures
```yaml
Data Encryption:
  - At Rest: AES-256 for all storage
  - In Transit: TLS 1.3 for all connections

Access Control:
  - IAM roles for service accounts
  - RBAC for user access
  - API key rotation every 90 days

Data Privacy:
  - PII encryption/tokenization
  - GDPR compliance for EU users
  - Data retention policies
  - Audit logging for all access
```

### 7.2 Compliance Requirements
- **Data Residency**: Region-specific storage
- **Right to Erasure**: Automated PII deletion
- **Consent Management**: Opt-in/out tracking
- **Audit Trail**: Complete event lineage

## 8. Disaster Recovery

### 8.1 Backup Strategy
- **Snowflake**: Time Travel (7 days) + External backup
- **PostgreSQL**: Daily snapshots + WAL archiving
- **Kafka**: Mirror Maker for cross-region replication

### 8.2 Recovery Targets
- **RPO**: 1 hour for batch, 5 minutes for real-time
- **RTO**: 30 minutes for critical components
- **Failover**: Automatic for stateless components

## 9. Implementation Roadmap

### Phase 1: Core Engine (Weeks 1-8)
- Basic rule evaluation engine
- PostgreSQL CDC setup
- Simple nudge generation
- MSK integration

### Phase 2: Advanced Features (Weeks 9-16)
- Complex rule conditions
- Batch processing pipeline
- API distribution layer
- Monitoring setup

### Phase 3: Data Fabric Layer (Weeks 17-20)
- Unified data access service
- Additional data source connectors
- Advanced caching layer

### Phase 4: Optimization (Weeks 21-24)
- Performance tuning
- ML-based rules
- A/B testing framework
- Advanced analytics

## 10. Technology Stack Summary

| Component | Primary Technology | Alternative Options |
|-----------|-------------------|-------------------|
| Stream Processing | Apache Flink | Kafka Streams, Apache Storm |
| Batch Processing | Apache Spark | Snowflake Tasks, Apache Beam |
| Message Queue | Amazon MSK | Apache Kafka, Apache Pulsar |
| Data Lake | Snowflake | Databricks, AWS Redshift |
| API Gateway | AWS API Gateway | Kong, Zuul |
| Caching | Redis | Hazelcast, Memcached |
| Monitoring | Prometheus + Grafana | DataDog, New Relic |
| Container Orchestration | Kubernetes | ECS, Docker Swarm |