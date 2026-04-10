// Package workflow provides workflow-scoped policy evaluation.
//
// Workflow-scoped policies apply at the workflow level rather than individual
// agent level. This enables policies that consider:
// - Aggregate cost across all agents
// - Total tool calls across the workflow
// - Cross-agent data flow patterns
// - Workflow-level compliance requirements
package workflow

import (
	"context"
	"fmt"
	"time"

	envelopev1 "github.com/fulcrum-io/fulcrum/pkg/envelope/v1"
	"github.com/fulcrum-io/fulcrum/pkg/policyeval"
)

// PolicyScope defines the scope at which a policy applies.
type PolicyScope string

const (
	// PolicyScopeAgent applies to individual agent executions.
	PolicyScopeAgent PolicyScope = "agent"

	// PolicyScopeWorkflow applies to entire workflow execution.
	PolicyScopeWorkflow PolicyScope = "workflow"
)

// WorkflowPolicyConfig configures workflow-scoped policy evaluation.
type WorkflowPolicyConfig struct {
	// Evaluator for policy evaluation
	Evaluator *policyeval.Evaluator

	// WorkflowPolicies are policy IDs that apply at workflow scope
	WorkflowPolicies []string

	// EnforceAggregateBudget enforces combined budget across all agents
	EnforceAggregateBudget bool

	// MaxWorkflowDuration limits total workflow execution time
	MaxWorkflowDuration time.Duration

	// MaxAgentCount limits the number of agents in a workflow
	MaxAgentCount int

	// MaxAgentDepth limits the hierarchy depth
	MaxAgentDepth int
}

// DefaultWorkflowPolicyConfig returns sensible defaults.
func DefaultWorkflowPolicyConfig() *WorkflowPolicyConfig {
	return &WorkflowPolicyConfig{
		EnforceAggregateBudget: true,
		MaxWorkflowDuration:    30 * time.Minute,
		MaxAgentCount:          100,
		MaxAgentDepth:          10,
	}
}

// WorkflowPolicyEvaluator evaluates policies at the workflow level.
type WorkflowPolicyEvaluator struct {
	config   *WorkflowPolicyConfig
	workflow *Workflow
}

// NewWorkflowPolicyEvaluator creates a new workflow policy evaluator.
func NewWorkflowPolicyEvaluator(workflow *Workflow, config *WorkflowPolicyConfig) *WorkflowPolicyEvaluator {
	if config == nil {
		config = DefaultWorkflowPolicyConfig()
	}

	return &WorkflowPolicyEvaluator{
		config:   config,
		workflow: workflow,
	}
}

// WorkflowEvaluationResult is the result of workflow-level policy evaluation.
type WorkflowEvaluationResult struct {
	// Allowed indicates if the action should proceed
	Allowed bool

	// Reason explains the decision
	Reason string

	// ViolatedPolicies lists policies that were violated
	ViolatedPolicies []string

	// Warnings are non-blocking policy concerns
	Warnings []string

	// AggregateCost at time of evaluation
	AggregateCost *envelopev1.CostSummary

	// BudgetRemaining for the workflow
	BudgetRemaining float64
}

// EvaluateToolCall evaluates a tool call against workflow-scoped policies.
// This is called in addition to agent-level policy evaluation.
func (wpe *WorkflowPolicyEvaluator) EvaluateToolCall(ctx context.Context, envelopeID, toolName string, args map[string]interface{}) (*WorkflowEvaluationResult, error) {
	result := &WorkflowEvaluationResult{
		Allowed:       true,
		AggregateCost: wpe.workflow.GetWorkflowCost(),
	}

	// Check workflow budget constraints
	if wpe.config.EnforceAggregateBudget {
		if err := wpe.checkBudgetConstraints(result); err != nil {
			return nil, err
		}
	}

	// Check agent count limits
	if wpe.config.MaxAgentCount > 0 {
		if wpe.workflow.GetEnvelopeCount() > wpe.config.MaxAgentCount {
			result.Allowed = false
			result.Reason = fmt.Sprintf("workflow agent limit exceeded: %d > %d",
				wpe.workflow.GetEnvelopeCount(), wpe.config.MaxAgentCount)
			result.ViolatedPolicies = append(result.ViolatedPolicies, "workflow_agent_limit")
			return result, nil
		}
	}

	// Check workflow duration
	if wpe.config.MaxWorkflowDuration > 0 {
		duration := time.Since(wpe.workflow.StartedAt)
		if duration > wpe.config.MaxWorkflowDuration {
			result.Allowed = false
			result.Reason = fmt.Sprintf("workflow duration exceeded: %v > %v",
				duration, wpe.config.MaxWorkflowDuration)
			result.ViolatedPolicies = append(result.ViolatedPolicies, "workflow_duration_limit")
			return result, nil
		}
	}

	// If evaluator is configured, evaluate workflow-scoped policies
	if wpe.config.Evaluator != nil && len(wpe.config.WorkflowPolicies) > 0 {
		evalResult, err := wpe.evaluatePolicies(ctx, envelopeID, toolName, args)
		if err != nil {
			return nil, fmt.Errorf("policy evaluation failed: %w", err)
		}

		if evalResult != nil {
			result.Allowed = evalResult.Allowed
			result.Reason = evalResult.Reason
			result.ViolatedPolicies = append(result.ViolatedPolicies, evalResult.ViolatedPolicies...)
			result.Warnings = append(result.Warnings, evalResult.Warnings...)
		}
	}

	return result, nil
}

// checkBudgetConstraints checks aggregate budget constraints.
func (wpe *WorkflowPolicyEvaluator) checkBudgetConstraints(result *WorkflowEvaluationResult) error {
	if wpe.workflow.governance == nil {
		return nil
	}

	cost := wpe.workflow.GetWorkflowCost()
	if cost == nil {
		return nil
	}

	// Check token budget
	if wpe.workflow.governance.TokenBudget > 0 {
		totalTokens := cost.TotalInputTokens + cost.TotalOutputTokens
		if totalTokens >= wpe.workflow.governance.TokenBudget {
			result.Allowed = false
			result.Reason = fmt.Sprintf("workflow token budget exhausted: %d >= %d",
				totalTokens, wpe.workflow.governance.TokenBudget)
			result.ViolatedPolicies = append(result.ViolatedPolicies, "workflow_token_budget")
			return nil
		}

		// Calculate remaining
		remainingTokens := wpe.workflow.governance.TokenBudget - totalTokens
		if remainingTokens < wpe.workflow.governance.TokenBudget/10 {
			result.Warnings = append(result.Warnings,
				fmt.Sprintf("workflow token budget low: %d remaining", remainingTokens))
		}
	}

	// Check cost budget
	if wpe.workflow.governance.CostLimitUsd > 0 {
		if cost.TotalCostUsd >= wpe.workflow.governance.CostLimitUsd {
			result.Allowed = false
			result.Reason = fmt.Sprintf("workflow cost budget exhausted: $%.2f >= $%.2f",
				cost.TotalCostUsd, wpe.workflow.governance.CostLimitUsd)
			result.ViolatedPolicies = append(result.ViolatedPolicies, "workflow_cost_budget")
			return nil
		}

		result.BudgetRemaining = wpe.workflow.governance.CostLimitUsd - cost.TotalCostUsd

		// Warn if budget is low
		if result.BudgetRemaining < wpe.workflow.governance.CostLimitUsd*0.1 {
			result.Warnings = append(result.Warnings,
				fmt.Sprintf("workflow cost budget low: $%.2f remaining", result.BudgetRemaining))
		}
	}

	// Check LLM call count
	if wpe.workflow.governance.MaxLlmCalls > 0 {
		if cost.LlmCallCount >= int32(wpe.workflow.governance.MaxLlmCalls) {
			result.Allowed = false
			result.Reason = fmt.Sprintf("workflow LLM call limit reached: %d >= %d",
				cost.LlmCallCount, wpe.workflow.governance.MaxLlmCalls)
			result.ViolatedPolicies = append(result.ViolatedPolicies, "workflow_llm_limit")
			return nil
		}
	}

	// Check tool call count
	if wpe.workflow.governance.MaxToolCalls > 0 {
		if cost.ToolCallCount >= int32(wpe.workflow.governance.MaxToolCalls) {
			result.Allowed = false
			result.Reason = fmt.Sprintf("workflow tool call limit reached: %d >= %d",
				cost.ToolCallCount, wpe.workflow.governance.MaxToolCalls)
			result.ViolatedPolicies = append(result.ViolatedPolicies, "workflow_tool_limit")
			return nil
		}
	}

	return nil
}

// evaluatePolicies evaluates workflow-scoped policies using the evaluator.
func (wpe *WorkflowPolicyEvaluator) evaluatePolicies(ctx context.Context, envelopeID, toolName string, args map[string]interface{}) (*WorkflowEvaluationResult, error) {
	if wpe.config.Evaluator == nil {
		return nil, nil
	}

	// Build evaluation request with workflow context
	req := &policyeval.EvaluationRequest{
		TenantID:   wpe.workflow.TenantID,
		ToolNames:  []string{toolName},
		EnvelopeID: envelopeID,
		WorkflowID: wpe.workflow.ID,
		Attributes: map[string]string{
			"workflow_name":  wpe.workflow.Name,
			"scope":          string(PolicyScopeWorkflow),
			"envelope_count": fmt.Sprintf("%d", wpe.workflow.GetEnvelopeCount()),
			"active_agents":  fmt.Sprintf("%d", wpe.workflow.GetActiveEnvelopeCount()),
		},
	}

	// Evaluate
	decision, err := wpe.config.Evaluator.Evaluate(ctx, req)
	if err != nil {
		return nil, err
	}

	result := &WorkflowEvaluationResult{
		Allowed: decision.Action == policyeval.ActionAllow || decision.Action == policyeval.ActionWarn,
		Reason:  decision.Reason,
	}

	switch decision.Action {
	case policyeval.ActionDeny:
		if decision.MatchedPolicy != nil {
			result.ViolatedPolicies = []string{decision.MatchedPolicy.PolicyId}
		}
	case policyeval.ActionWarn:
		result.Warnings = []string{decision.Reason}
	}

	return result, nil
}

// EvaluateAgentSpawn checks if a new agent can be spawned in the workflow.
func (wpe *WorkflowPolicyEvaluator) EvaluateAgentSpawn(ctx context.Context, parentEnvelopeID, agentName string, depth int) (*WorkflowEvaluationResult, error) {
	result := &WorkflowEvaluationResult{
		Allowed:       true,
		AggregateCost: wpe.workflow.GetWorkflowCost(),
	}

	// Check agent count limit
	if wpe.config.MaxAgentCount > 0 {
		if wpe.workflow.GetEnvelopeCount() >= wpe.config.MaxAgentCount {
			result.Allowed = false
			result.Reason = fmt.Sprintf("cannot spawn agent: workflow agent limit reached (%d)",
				wpe.config.MaxAgentCount)
			result.ViolatedPolicies = append(result.ViolatedPolicies, "workflow_agent_limit")
			return result, nil
		}
	}

	// Check depth limit
	if wpe.config.MaxAgentDepth > 0 && depth >= wpe.config.MaxAgentDepth {
		result.Allowed = false
		result.Reason = fmt.Sprintf("cannot spawn agent: max depth reached (%d)",
			wpe.config.MaxAgentDepth)
		result.ViolatedPolicies = append(result.ViolatedPolicies, "workflow_depth_limit")
		return result, nil
	}

	// Check budget for new agent
	if wpe.config.EnforceAggregateBudget {
		if err := wpe.checkBudgetConstraints(result); err != nil {
			return nil, err
		}
		if !result.Allowed {
			return result, nil
		}
	}

	return result, nil
}

// GetWorkflowBudgetStatus returns the current budget status for the workflow.
func (wpe *WorkflowPolicyEvaluator) GetWorkflowBudgetStatus() *WorkflowBudgetStatus {
	cost := wpe.workflow.GetWorkflowCost()
	if cost == nil {
		cost = &envelopev1.CostSummary{}
	}

	status := &WorkflowBudgetStatus{
		WorkflowID:       wpe.workflow.ID,
		TotalTokens:      cost.TotalInputTokens + cost.TotalOutputTokens,
		TotalCostUSD:     cost.TotalCostUsd,
		LLMCalls:         cost.LlmCallCount,
		ToolCalls:        cost.ToolCallCount,
		AgentCount:       wpe.workflow.GetEnvelopeCount(),
		ActiveAgents:     wpe.workflow.GetActiveEnvelopeCount(),
		WorkflowDuration: time.Since(wpe.workflow.StartedAt),
	}

	// Calculate remaining if governance is set
	if wpe.workflow.governance != nil {
		if wpe.workflow.governance.TokenBudget > 0 {
			status.TokenBudget = wpe.workflow.governance.TokenBudget
			status.TokensRemaining = wpe.workflow.governance.TokenBudget - status.TotalTokens
		}
		if wpe.workflow.governance.CostLimitUsd > 0 {
			status.CostBudgetUSD = wpe.workflow.governance.CostLimitUsd
			status.CostRemaining = wpe.workflow.governance.CostLimitUsd - status.TotalCostUSD
		}
	}

	return status
}

// WorkflowBudgetStatus represents budget usage at workflow level.
type WorkflowBudgetStatus struct {
	WorkflowID       string
	TotalTokens      int64
	TokenBudget      int64
	TokensRemaining  int64
	TotalCostUSD     float64
	CostBudgetUSD    float64
	CostRemaining    float64
	LLMCalls         int32
	ToolCalls        int32
	AgentCount       int
	ActiveAgents     int
	WorkflowDuration time.Duration
}
