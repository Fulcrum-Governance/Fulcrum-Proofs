// Package policyengine provides policy evaluation and enforcement for Fulcrum executions.
package policyengine

import (
	"context"
	"database/sql"
	"fmt"
	"sync"
	"time"

	"github.com/fulcrum-io/fulcrum/internal/brain"
	"github.com/fulcrum-io/fulcrum/internal/logging"
	eventstorev1 "github.com/fulcrum-io/fulcrum/pkg/eventstore/v1"
	policyv1 "github.com/fulcrum-io/fulcrum/pkg/policy/v1"
	"github.com/nats-io/nats.go"
	"go.uber.org/zap"
	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/structpb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// PolicyInterceptor monitors execution events and evaluates policies at intercept points.
//
// # Concurrency Design
//
// PolicyInterceptor uses separate RWMutex locks for policies and baselines to maximize
// concurrent read throughput. This design choice is intentional:
//
//   - policiesMu: Protects the policies map. Policies are read frequently during
//     evaluation but updated infrequently (admin operations).
//
//   - baselinesMu: Protects the baselines map. Baselines are updated by the background
//     statistics collector and read during anomaly detection.
//
// Separate locks allow policy evaluation to proceed concurrently with baseline updates,
// avoiding unnecessary contention. Lock ordering is not required as these maps are
// independent—no operation holds both locks simultaneously.
//
// # Thread Safety
//
// All public methods are safe for concurrent use. The shutdown channel and WaitGroup
// coordinate graceful termination of background goroutines.
type PolicyInterceptor struct {
	nc        *nats.Conn
	js        nats.JetStreamContext
	db        *sql.DB
	evaluator *Evaluator
	immune    *brain.ImmuneSystem

	// policiesMu protects concurrent access to the policies map.
	// Use RLock for reads (evaluation), Lock for writes (add/remove policy).
	policies   map[string]*policyv1.Policy // policyID -> Policy
	policiesMu sync.RWMutex

	// Configuration
	enableLogging bool

	// Shutdown coordination for background goroutines
	shutdown chan struct{}
	wg       sync.WaitGroup

	// baselinesMu protects concurrent access to statistical baselines.
	// Updated by background collector, read during anomaly detection.
	// Separate from policiesMu to avoid contention during evaluation.
	baselines   map[string]map[string]baselineStats // workflowID -> field -> stats
	baselinesMu sync.RWMutex
}

type baselineStats struct {
	avg    float64
	stddev float64
}

// NewPolicyInterceptor creates a new policy interceptor.
func NewPolicyInterceptor(nc *nats.Conn, db *sql.DB, immune *brain.ImmuneSystem) (*PolicyInterceptor, error) {
	js, err := nc.JetStream()
	if err != nil {
		return nil, fmt.Errorf("failed to create JetStream context: %w", err)
	}

	pi := &PolicyInterceptor{
		nc:            nc,
		js:            js,
		db:            db,
		evaluator:     NewEvaluator(),
		policies:      make(map[string]*policyv1.Policy),
		baselines:     make(map[string]map[string]baselineStats),
		immune:        immune,
		enableLogging: true,
		shutdown:      make(chan struct{}),
	}

	return pi, nil
}

// AddPolicy registers a policy for evaluation.
func (pi *PolicyInterceptor) AddPolicy(policy *policyv1.Policy) error {
	if err := ValidatePolicy(policy); err != nil {
		return fmt.Errorf("invalid policy: %w", err)
	}

	pi.policiesMu.Lock()
	pi.policies[policy.PolicyId] = policy
	pi.policiesMu.Unlock()

	if pi.enableLogging {
		logging.Info("registered policy",
			logging.PolicyID(policy.PolicyId),
			zap.String("name", policy.Name))
	}

	return nil
}

// RemovePolicy removes a policy from evaluation.
func (pi *PolicyInterceptor) RemovePolicy(policyID string) {
	pi.policiesMu.Lock()
	defer pi.policiesMu.Unlock()
	delete(pi.policies, policyID)
}

// Start begins monitoring events on the execution event stream.
func (pi *PolicyInterceptor) Start(ctx context.Context) error {
	subject := "fulcrum.events.execution.>"
	durableName := "FULCRUM_POLICY_ENGINE"

	// Use Durable Consumer for reliability across restarts
	// ExplicitAck ensures we only acknowledge once evaluation is complete
	sub, err := pi.js.Subscribe(subject, pi.handleMessage,
		nats.Durable(durableName),
		nats.DeliverNew(),
		nats.AckExplicit(),
		nats.MaxDeliver(5), // Retry up to 5 times if evaluation fails
	)
	if err != nil {
		return fmt.Errorf("failed to subscribe to %s: %w", subject, err)
	}

	if pi.enableLogging {
		logging.Info("policy interceptor subscribed",
			zap.String("durable", durableName),
			zap.String("subject", subject))
	}

	// Track subscription for cleanup
	pi.wg.Add(1)
	go func() {
		defer pi.wg.Done()
		<-ctx.Done()
		_ = sub.Unsubscribe()
	}()

	return nil
}

// Stop gracefully shuts down the policy interceptor.
// It signals all background goroutines to terminate and waits for them to complete.
// The timeout parameter specifies the maximum time to wait for graceful shutdown.
// If timeout is 0, it waits indefinitely. Returns an error if shutdown times out.
func (pi *PolicyInterceptor) Stop(timeout time.Duration) error {
	// Signal shutdown to all background goroutines
	close(pi.shutdown)

	// Wait for goroutines with optional timeout
	done := make(chan struct{})
	go func() {
		pi.wg.Wait()
		close(done)
	}()

	if timeout == 0 {
		<-done
		return nil
	}

	select {
	case <-done:
		return nil
	case <-time.After(timeout):
		return fmt.Errorf("graceful shutdown timed out after %v", timeout)
	}
}

func (pi *PolicyInterceptor) handleMessage(msg *nats.Msg) {
	// Always ack if we finish processing
	defer func() { _ = msg.Ack() }()

	var event eventstorev1.StoredEvent
	if err := proto.Unmarshal(msg.Data, &event); err != nil {
		if pi.enableLogging {
			logging.Error("failed to unmarshal event", logging.Err(err))
		}
		return
	}

	// Dispatch to policy evaluation based on event type
	switch event.EventType {
	case "execution_started":
		pi.evaluateEvent(&event, policyv1.ExecutionPhase_EXECUTION_PHASE_PRE_EXECUTION)
	case "llm_call_started", "llm_call": // Treat 'llm_call' as started if no _completed suffix
		pi.evaluateEvent(&event, policyv1.ExecutionPhase_EXECUTION_PHASE_PRE_LLM_CALL)
	case "llm_call_completed":
		pi.evaluateEvent(&event, policyv1.ExecutionPhase_EXECUTION_PHASE_POST_LLM_CALL)
	}
}

// evaluateEvent handles policy evaluation for a specific event and phase.
func (pi *PolicyInterceptor) evaluateEvent(event *eventstorev1.StoredEvent, phase policyv1.ExecutionPhase) {
	// Build evaluation context from event
	evalCtx := &policyv1.EvaluationContext{
		TenantId:   event.TenantId,
		EnvelopeId: event.EnvelopeId,
		WorkflowId: event.WorkflowId,
		Phase:      phase,
		Timestamp:  event.Timestamp,
		Attributes: make(map[string]string),
	}

	// Add execution ID to attributes since it's not in the proto
	evalCtx.Attributes["execution_id"] = event.ExecutionId

	// Extract additional context from the event's payload
	pi.extractContextFromPayload(evalCtx, event)

	// Inject statistical baselines for anomaly detection
	pi.injectBaselines(evalCtx)

	if pi.enableLogging {
		logging.Debug("evaluating envelope",
			logging.EnvelopeID(event.EnvelopeId),
			zap.String("model_id", evalCtx.ModelId),
			zap.String("phase", evalCtx.Phase.String()))
	}

	// Get applicable policies for this phase
	policies := pi.getApplicablePolicies(phase)
	if len(policies) == 0 {
		return // No policies to evaluate
	}

	// Evaluate policies individually to correctly attribute decisions
	for _, policy := range policies {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		result, err := pi.evaluator.EvaluatePolicy(ctx, policy, evalCtx)
		cancel()
		if err != nil {
			if pi.enableLogging {
				logging.Error("policy evaluation error",
					logging.PolicyID(policy.PolicyId),
					logging.Err(err))
			}
			continue
		}

		// Emit policy evaluation result event (per policy)
		pi.emitPolicyEvent(event, result, phase)

		// Handle policy decisions
		switch result.Decision {
		case policyv1.EvaluationDecision_EVALUATION_DECISION_DENY:
			pi.handlePolicyViolation(event, result, phase)
			// Deny stops further evaluation and execution
			return
		case policyv1.EvaluationDecision_EVALUATION_DECISION_REQUIRE_APPROVAL:
			pi.handlePolicyApproval(event, result, phase)
			// Approval acts as a block until resolved.
			// In a synchronous interceptor, this would block.
			// Here (async), it signals a pause.
		case policyv1.EvaluationDecision_EVALUATION_DECISION_WARN:
			if pi.enableLogging {
				logging.Warn("policy warning",
					logging.EnvelopeID(event.EnvelopeId),
					zap.String("message", result.Message))
			}
		}

		// Trigger notifications if any (Task 403)
		for _, action := range result.Actions {
			if action.ActionType == policyv1.ActionType_ACTION_TYPE_NOTIFY {
				pi.handlePolicyNotification(event, result, action)
			}
		}
	}
}

func (pi *PolicyInterceptor) handlePolicyNotification(event *eventstorev1.StoredEvent, result *policyv1.EvaluationResult, action *policyv1.PolicyAction) {
	if pi.enableLogging {
		logging.Info("policy notification triggered",
			logging.EnvelopeID(event.EnvelopeId),
			logging.PolicyID(result.PolicyId),
			zap.String("message", result.Message),
			zap.String("channel", action.Parameters["channel"]))
	}
}

func (pi *PolicyInterceptor) handlePolicyApproval(event *eventstorev1.StoredEvent, result *policyv1.EvaluationResult, phase policyv1.ExecutionPhase) {
	if pi.enableLogging {
		logging.Info("policy approval required",
			logging.EnvelopeID(event.EnvelopeId),
			zap.String("message", result.Message))
	}

	var evaluationUUID string

	if pi.db == nil {
		if pi.enableLogging {
			logging.Warn("review required but no DB configured")
		}
		return
	}

	// 1. Insert Evaluation Record
	// Use result.PolicyId which is now populated from EvaluatePolicy
	// Marshal context for storage
	ctxJSON, _ := protojson.Marshal(result.Context)

	err := pi.db.QueryRow(`
		INSERT INTO fulcrum.policy_evaluations (envelope_id, policy_id, decision, message, context)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id
	`, event.EnvelopeId, result.PolicyId, "REQUIRE_APPROVAL", result.Message, ctxJSON).Scan(&evaluationUUID)
	if err != nil {
		if pi.enableLogging {
			logging.Error("failed to insert policy evaluation for approval", logging.Err(err))
		}
		return
	}

	// 2. Insert Approval Record
	_, err = pi.db.Exec(`
		INSERT INTO fulcrum.policy_approvals (evaluation_id, status)
		VALUES ($1, 'PENDING')
	`, evaluationUUID)
	if err != nil {
		if pi.enableLogging {
			logging.Error("failed to create policy approval", logging.Err(err))
		}
		return
	}

	// 3. Emit Paused Event
	storedEvent := &eventstorev1.StoredEvent{
		EventId:     fmt.Sprintf("pause-%d", time.Now().UnixNano()),
		ExecutionId: event.ExecutionId,
		EnvelopeId:  event.EnvelopeId,
		TenantId:    event.TenantId,
		EventType:   "execution_paused",
		Timestamp:   timestamppb.Now(),
		StoredAt:    timestamppb.Now(),
	}

	payload, _ := structpb.NewStruct(map[string]interface{}{
		"reason":    "approval_required",
		"message":   result.Message,
		"policy_id": result.PolicyId,
	})
	storedEvent.Payload = payload

	data, _ := proto.Marshal(storedEvent)
	subject := fmt.Sprintf("fulcrum.events.execution.%s", event.ExecutionId)
	if err := pi.nc.Publish(subject, data); err != nil {
		if pi.enableLogging {
			logging.Error("failed to publish pause event",
				zap.String("subject", subject),
				logging.Err(err))
		}
	}
}
