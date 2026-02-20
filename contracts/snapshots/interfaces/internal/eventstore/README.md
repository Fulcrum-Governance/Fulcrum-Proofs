# Event Store Package

Durable event persistence using NATS JetStream for Fulcrum audit and replay capabilities.

## Purpose

The event store provides:
- Durable event streaming for all Fulcrum operations
- Audit log persistence for compliance
- Event replay for debugging and analysis
- Checkpoint management for long-running workflows

## Quick Start

```go
package main

import (
    "context"
    "fmt"
    "log"

    "github.com/fulcrum-io/fulcrum/internal/eventstore"
    "github.com/google/uuid"
    "google.golang.org/protobuf/types/known/timestamppb"
)

func main() {
    ctx := context.Background()

    // Create event store
    cfg := &eventstore.Config{
        NATSUrl:       "nats://localhost:4222",
        RetentionDays: 7,
    }

    store, err := eventstore.NewEventStore(cfg)
    if err != nil {
        log.Fatal(err)
    }
    defer store.Close()

    // Publish an event
    event := &eventstore.ExecutionEvent{
        EventId:   uuid.New().String(),
        TenantId:  "tenant-123",
        EventType: eventstore.EventTypeWorkflowStarted,
        Timestamp: timestamppb.Now(),
    }

    err = store.Publish(ctx, eventstore.StreamExecutionEvents, event)
    if err != nil {
        log.Fatal(err)
    }

    fmt.Printf("Published event: %s\n", event.EventId)
    fmt.Printf("Stream: %s\n", eventstore.StreamExecutionEvents)
    fmt.Println("Status: Success")
}
```

**Expected Output:**
```
Published event: 550e8400-e29b-41d4-a716-446655440000
Stream: FULCRUM_EXECUTION_EVENTS
Status: Success
```

**Prerequisites:**
- NATS JetStream running: `docker run -d -p 4222:4222 nats:latest -js`

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Event Store                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   NATS JetStream                         │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  FULCRUM_EXECUTION_EVENTS  │  Workflow executions       │   │
│  │  FULCRUM_LLM_EVENTS        │  LLM requests/responses    │   │
│  │  FULCRUM_TOOL_EVENTS       │  Tool invocations          │   │
│  │  FULCRUM_CHECKPOINTS       │  Workflow checkpoints      │   │
│  │  FULCRUM_AUDIT_LOG         │  Audit trail               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐ │
│  │     Publish      │  │    Subscribe     │  │     Query     │ │
│  │                  │  │                  │  │               │ │
│  │  - Proto encode  │  │  - Consumer grp  │  │  - By time    │ │
│  │  - Ack handling  │  │  - Replay        │  │  - By tenant  │ │
│  │  - Retry logic   │  │  - Filtering     │  │  - By type    │ │
│  └──────────────────┘  └──────────────────┘  └───────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Streams

| Stream | Purpose | Retention |
|--------|---------|-----------|
| `FULCRUM_EXECUTION_EVENTS` | Workflow start/end events | 7 days |
| `FULCRUM_LLM_EVENTS` | LLM request/response pairs | 7 days |
| `FULCRUM_TOOL_EVENTS` | Tool invocation records | 7 days |
| `FULCRUM_CHECKPOINTS` | Workflow state snapshots | 30 days |
| `FULCRUM_AUDIT_LOG` | Compliance audit trail | 365 days |

## Usage

### Creating an Event Store

```go
cfg := &eventstore.Config{
    NATSUrl:              "nats://localhost:4222",
    RetentionDays:        7,
    MaxMessagesPerStream: 1000000,
    MaxBytesPerStream:    1073741824, // 1GB
}

store, err := eventstore.NewEventStore(cfg)
if err != nil {
    log.Fatal(err)
}
defer store.Close()
```

### Publishing Events

```go
event := &eventstorev1.ExecutionEvent{
    EventId:   uuid.New().String(),
    TenantId:  "tenant-123",
    EventType: eventstorev1.EventType_EVENT_TYPE_WORKFLOW_STARTED,
    Timestamp: timestamppb.Now(),
    Payload: &structpb.Struct{
        Fields: map[string]*structpb.Value{
            "workflow_id": structpb.NewStringValue("wf-001"),
        },
    },
}

err := store.Publish(ctx, eventstore.StreamExecutionEvents, event)
```

### Subscribing to Events

```go
handler := func(event *eventstorev1.ExecutionEvent) error {
    log.Printf("Received event: %s", event.EventId)
    return nil
}

sub, err := store.Subscribe(ctx, eventstore.StreamExecutionEvents, "my-consumer", handler)
if err != nil {
    log.Fatal(err)
}
defer sub.Unsubscribe()
```

### Querying Events

```go
events, err := store.QueryByTenant(ctx, "tenant-123",
    eventstore.WithTimeRange(startTime, endTime),
    eventstore.WithEventType(eventstorev1.EventType_EVENT_TYPE_TOOL_CALLED),
    eventstore.WithLimit(100),
)
```

## Testing

```bash
# Run tests (requires NATS)
go test ./internal/eventstore/...

# Run with coverage
go test ./internal/eventstore/... -coverprofile=cover.out

# Start test NATS server
docker run -d --name nats -p 4222:4222 nats:latest -js
```

## Performance

| Operation | Target | Notes |
|-----------|--------|-------|
| Publish | <5ms | Single event |
| Subscribe latency | <10ms | End-to-end |
| Query (100 events) | <50ms | With filtering |

## Configuration

### Environment Variables

```bash
NATS_URL=nats://localhost:4222
EVENTSTORE_RETENTION_DAYS=7
EVENTSTORE_MAX_MESSAGES=1000000
```

### Stream Configuration

Streams are automatically created on startup with:
- `WorkQueuePolicy` for exactly-once delivery
- `FileStorage` for durability
- Configurable retention based on stream type

## Error Handling

```go
// Publish with retry
err := store.PublishWithRetry(ctx, stream, event, 3)
if errors.Is(err, eventstore.ErrStreamFull) {
    // Handle capacity issue
}

// Subscribe with error callback
sub, err := store.Subscribe(ctx, stream, consumer, handler,
    eventstore.WithErrorHandler(func(err error) {
        log.Printf("Subscription error: %v", err)
    }),
)
```

## Related Packages

- `internal/brain` - Immune System publishes incidents
- `internal/envelopeservice` - Publishes envelope lifecycle events
- `pkg/eventstore/v1` - Protocol buffer definitions
- `pkg/observability` - OpenTelemetry tracing integration
