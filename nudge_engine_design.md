# Nudge Generation Engine - Low Level Solution Design

## 1. System Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │    Snowflake    │    │  Other Sources  │
│      ODS        │    │   Data Lake     │    │  (APIs, Files)  │
│  (Real-time)    │    │ (Near RT/Batch) │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Data Fabric    │
                    │    Layer        │
                    │   (Optional)    │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │ Event Ingestion │
                    │    Gateway      │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐    ┌─────────────────┐
                    │ Nudge Generation│    │   Rules DB      │
                    │     Engine      │────│   (PostgreSQL)  │
                    └─────────────────┘    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │ Nudge Processor │
                    │   & Publisher   │
                    └─────────────────┘
                                 │
            ┌────────────────────┼────────────────────┐
            │                    │                    │
   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
   │      MSK        │  │   Nudge Store   │  │   API Gateway   │
   │   (Kafka)       │  │ (PostgreSQL/    │  │  for Nudge      │
   │                 │  │   NoSQL)        │  │ Distribution    │
   └─────────────────┘  └─────────────────┘  └─────────────────┘
```

## 2. Component Details

### 2.1 Data Fabric Layer (Optional)
**Purpose**: Unified data access layer providing abstraction over multiple data sources

**Components**:
- **Data Source Connectors**
  - PostgreSQL ODS Connector
  - Snowflake Connector  
  - Generic REST API Connector
  - File System Connector
- **Query Federation Engine**
- **Data Catalog & Metadata Management**
- **Caching Layer (Redis)**

**Technology Stack**:
- Apache Drill / Presto for query federation
- Apache Atlas for metadata management
- Redis for caching
- Spring Boot for service layer

**Implementation**:
```java
@Component
public class DataFabricService {
    
    @Autowired
    private Map<String, DataSourceConnector> connectors;
    
    public EventData fetchEvents(DataSourceQuery query) {
        String sourceType = query.getSourceType();
        DataSourceConnector connector = connectors.get(sourceType);
        return connector.executeQuery(query);
    }
}

interface DataSourceConnector {
    EventData executeQuery(DataSourceQuery query);
    boolean supportsRealTime();
}
```

### 2.2 Event Ingestion Gateway
**Purpose**: Centralized event ingestion with routing and transformation

**Features**:
- Event validation and enrichment
- Schema registry integration
- Rate limiting and throttling
- Dead letter queue handling

**Technology Stack**:
- Spring Boot with WebFlux for reactive programming
- Apache Avro for schema management
- Redis for rate limiting

**Implementation**:
```java
@RestController
public class EventIngestionController {
    
    @PostMapping("/events")
    public Mono<ResponseEntity<String>> ingestEvent(
            @RequestBody EventPayload payload,
            @RequestHeader("source-type") String sourceType) {
        
        return eventValidationService
            .validate(payload)
            .flatMap(validatedPayload -> 
                eventEnrichmentService.enrich(validatedPayload, sourceType))
            .flatMap(enrichedPayload -> 
                nudgeGenerationService.processEvent(enrichedPayload))
            .map(result -> ResponseEntity.ok(result))
            .onErrorReturn(ResponseEntity.status(HttpStatus.BAD_REQUEST).build());
    }
}
```

### 2.3 Rules Database Schema
**Database**: PostgreSQL

```sql
-- Rules Definition Table
CREATE TABLE nudge_rules (
    rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_name VARCHAR(255) NOT NULL,
    rule_description TEXT,
    event_type VARCHAR(100) NOT NULL,
    conditions JSONB NOT NULL, -- Rule conditions in JSON format
    nudge_template JSONB NOT NULL, -- Nudge content template
    priority INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100),
    target_audience JSONB, -- Target user segments
    frequency_rules JSONB -- Frequency capping rules
);

-- Rule Execution Log
CREATE TABLE rule_execution_log (
    execution_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID REFERENCES nudge_rules(rule_id),
    event_id VARCHAR(255),
    user_id VARCHAR(100),
    execution_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    execution_status VARCHAR(50), -- SUCCESS, FAILED, SKIPPED
    execution_details JSONB,
    processing_time_ms INTEGER
);

-- Nudge Frequency Tracking
CREATE TABLE nudge_frequency_tracker (
    tracker_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(100) NOT NULL,
    rule_id UUID REFERENCES nudge_rules(rule_id),
    nudge_count INTEGER DEFAULT 0,
    last_nudge_sent TIMESTAMP,
    reset_date DATE,
    UNIQUE(user_id, rule_id, reset_date)
);
```

### 2.4 Nudge Generation Engine
**Purpose**: Core engine that evaluates events against rules and generates nudges

**Key Components**:
- Rule Engine (Drools or custom implementation)
- Event Matcher
- Nudge Generator
- Frequency Manager

**Technology Stack**:
- Spring Boot
- Drools Rule Engine or custom rule evaluation
- Jackson for JSON processing
- Micrometer for metrics

**Implementation**:
```java
@Service
public class NudgeGenerationEngine {
    
    @Autowired
    private RuleRepository ruleRepository;
    
    @Autowired
    private FrequencyManager frequencyManager;
    
    @Autowired
    private NudgeTemplateService templateService;
    
    public List<GeneratedNudge> processEvent(EventPayload event) {
        List<NudgeRule> applicableRules = ruleRepository
            .findActiveRulesByEventType(event.getEventType());
            
        return applicableRules.stream()
            .filter(rule -> evaluateRule(rule, event))
            .filter(rule -> frequencyManager.canSendNudge(
                event.getUserId(), rule.getRuleId()))
            .map(rule -> generateNudge(rule, event))
            .collect(Collectors.toList());
    }
    
    private boolean evaluateRule(NudgeRule rule, EventPayload event) {
        RuleEvaluator evaluator = new RuleEvaluator();
        return evaluator.evaluate(rule.getConditions(), event);
    }
    
    private GeneratedNudge generateNudge(NudgeRule rule, EventPayload event) {
        NudgeTemplate template = templateService.getTemplate(rule.getNudgeTemplate());
        return template.populateWith(event, rule);
    }
}
```

### 2.5 Rule Evaluation Engine
**Custom JSON-based Rule Engine**:

```java
@Component
public class RuleEvaluator {
    
    public boolean evaluate(JsonNode conditions, EventPayload event) {
        return evaluateCondition(conditions, event);
    }
    
    private boolean evaluateCondition(JsonNode condition, EventPayload event) {
        String operator = condition.get("operator").asText();
        
        switch (operator) {
            case "AND":
                return condition.get("conditions").elements()
                    .asIterator().forEachRemaining(c -> 
                        evaluateCondition(c, event));
                        
            case "OR":
                return StreamSupport.stream(condition.get("conditions").spliterator(), false)
                    .anyMatch(c -> evaluateCondition(c, event));
                    
            case "EQUALS":
                return evaluateEquals(condition, event);
                
            case "GREATER_THAN":
                return evaluateGreaterThan(condition, event);
                
            case "CONTAINS":
                return evaluateContains(condition, event);
                
            default:
                throw new IllegalArgumentException("Unknown operator: " + operator);
        }
    }
    
    // Individual operator implementations...
}
```

### 2.6 Nudge Storage Schema
**Database**: PostgreSQL

```sql
-- Generated Nudges Storage
CREATE TABLE generated_nudges (
    nudge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(100) NOT NULL,
    rule_id UUID REFERENCES nudge_rules(rule_id),
    event_id VARCHAR(255),
    nudge_type VARCHAR(50), -- PUSH, EMAIL, IN_APP, SMS
    nudge_content JSONB NOT NULL,
    nudge_metadata JSONB,
    status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, SENT, DELIVERED, FAILED, DISMISSED
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMP,
    delivery_status_updated_at TIMESTAMP,
    channel_specific_id VARCHAR(255), -- External system reference
    priority INTEGER DEFAULT 1,
    expires_at TIMESTAMP
);

-- Nudge Delivery Tracking
CREATE TABLE nudge_delivery_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nudge_id UUID REFERENCES generated_nudges(nudge_id),
    delivery_attempt INTEGER,
    delivery_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    delivery_status VARCHAR(50),
    delivery_response JSONB,
    retry_after TIMESTAMP
);

-- User Nudge Interactions
CREATE TABLE nudge_interactions (
    interaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nudge_id UUID REFERENCES generated_nudges(nudge_id),
    user_id VARCHAR(100),
    interaction_type VARCHAR(50), -- VIEWED, CLICKED, DISMISSED, CONVERTED
    interaction_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    interaction_metadata JSONB
);
```

### 2.7 MSK Publisher
**Purpose**: Publish generated nudges to Kafka for downstream consumption

**Implementation**:
```java
@Service
public class NudgePublisher {
    
    @Autowired
    private KafkaTemplate<String, Object> kafkaTemplate;
    
    @Value("${kafka.topics.nudges}")
    private String nudgesTopic;
    
    public void publishNudge(GeneratedNudge nudge) {
        NudgeEvent event = NudgeEvent.builder()
            .nudgeId(nudge.getNudgeId())
            .userId(nudge.getUserId())
            .eventType("NUDGE_GENERATED")
            .payload(nudge)
            .timestamp(Instant.now())
            .build();
            
        kafkaTemplate.send(nudgesTopic, nudge.getUserId(), event)
            .addCallback(
                result -> logSuccess(nudge.getNudgeId()),
                failure -> handlePublishFailure(nudge, failure)
            );
    }
}
```

### 2.8 API Gateway for Nudge Distribution
**Purpose**: RESTful APIs for nudge retrieval and management

**Endpoints**:
```java
@RestController
@RequestMapping("/api/v1/nudges")
public class NudgeDistributionController {
    
    @GetMapping("/user/{userId}")
    public ResponseEntity<List<NudgeResponse>> getUserNudges(
            @PathVariable String userId,
            @RequestParam(defaultValue = "PENDING") String status,
            @RequestParam(defaultValue = "10") int limit) {
        // Implementation
    }
    
    @PostMapping("/{nudgeId}/interactions")
    public ResponseEntity<Void> recordInteraction(
            @PathVariable UUID nudgeId,
            @RequestBody InteractionRequest request) {
        // Implementation
    }
    
    @PutMapping("/{nudgeId}/status")
    public ResponseEntity<Void> updateNudgeStatus(
            @PathVariable UUID nudgeId,
            @RequestBody StatusUpdateRequest request) {
        // Implementation
    }
}
```

## 3. Data Flow Architecture

### 3.1 Real-time Processing Flow (PostgreSQL ODS)
```
PostgreSQL ODS → CDC (Debezium) → Kafka → Event Ingestion Gateway 
→ Nudge Generation Engine → Rule Evaluation → Nudge Generation 
→ [MSK Publish + Database Store] → API Distribution
```

### 3.2 Near Real-time/Batch Processing Flow (Snowflake)
```
Snowflake → Scheduled Jobs/Streaming → Data Fabric Layer 
→ Event Ingestion Gateway → Nudge Generation Engine 
→ Rule Evaluation → Nudge Generation → [MSK Publish + Database Store] 
→ API Distribution
```

## 4. Configuration Management

### 4.1 Application Properties
```yaml
# Data Sources
spring:
  datasource:
    ods:
      url: jdbc:postgresql://ods-host:5432/ods_db
      username: ${ODS_DB_USER}
      password: ${ODS_DB_PASSWORD}
    rules:
      url: jdbc:postgresql://rules-host:5432/rules_db
      username: ${RULES_DB_USER}
      password: ${RULES_DB_PASSWORD}
    nudges:
      url: jdbc:postgresql://nudges-host:5432/nudges_db
      username: ${NUDGES_DB_USER}
      password: ${NUDGES_DB_PASSWORD}

# Snowflake Configuration
snowflake:
  url: ${SNOWFLAKE_URL}
  username: ${SNOWFLAKE_USER}
  password: ${SNOWFLAKE_PASSWORD}
  warehouse: ${SNOWFLAKE_WAREHOUSE}
  database: ${SNOWFLAKE_DATABASE}

# Kafka Configuration
kafka:
  bootstrap-servers: ${MSK_BOOTSTRAP_SERVERS}
  topics:
    nudges: nudge-events
    dlq: nudge-dlq
  producer:
    retries: 3
    batch-size: 16384
    linger-ms: 5

# Processing Configuration
nudge:
  processing:
    batch-size: 100
    thread-pool-size: 10
    retry-attempts: 3
  frequency:
    default-daily-limit: 5
    default-weekly-limit: 15
```

## 5. Monitoring and Observability

### 5.1 Key Metrics
- Event processing rate
- Rule evaluation latency
- Nudge generation success/failure rate
- Database connection pool metrics
- Kafka publish success rate

### 5.2 Alerting
- High error rates in rule evaluation
- Database connection failures
- Kafka publish failures
- Processing lag exceeding thresholds

### 5.3 Logging Strategy
```java
@Component
public class NudgeProcessingLogger {
    
    private static final Logger logger = LoggerFactory.getLogger(NudgeProcessingLogger.class);
    
    public void logEventProcessing(String eventId, String eventType, int rulesMatched) {
        logger.info("Event processed: eventId={}, type={}, rulesMatched={}", 
                   eventId, eventType, rulesMatched);
    }
    
    public void logNudgeGeneration(String nudgeId, String userId, String ruleId) {
        logger.info("Nudge generated: nudgeId={}, userId={}, ruleId={}", 
                   nudgeId, userId, ruleId);
    }
}
```

## 6. Deployment Architecture

### 6.1 Containerization
```dockerfile
FROM openjdk:17-jdk-slim
COPY target/nudge-engine.jar app.jar
ENTRYPOINT ["java","-jar","/app.jar"]
```

### 6.2 Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nudge-generation-engine
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nudge-engine
  template:
    metadata:
      labels:
        app: nudge-engine
    spec:
      containers:
      - name: nudge-engine
        image: nudge-engine:latest
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: "production"
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
```

## 7. Security Considerations

### 7.1 Authentication & Authorization
- JWT-based authentication for API endpoints
- Database connection encryption
- Secret management using Kubernetes secrets or HashiCorp Vault

### 7.2 Data Privacy
- PII data encryption at rest and in transit
- Data retention policies
- GDPR compliance for user data

## 8. Performance Optimization

### 8.1 Database Optimization
- Proper indexing on frequently queried columns
- Connection pooling
- Read replicas for query distribution

### 8.2 Caching Strategy
- Redis for frequently accessed rules
- Application-level caching for nudge templates
- Database query result caching

### 8.3 Async Processing
- Non-blocking I/O for external system calls
- Bulk processing for batch operations
- Queue-based processing for high-volume events

This design provides a scalable, maintainable solution for your nudge generation engine with clear separation of concerns and robust error handling.