// Package policyengine provides policy evaluation and enforcement for Fulcrum executions.
package policyengine

import (
	"context"
	"fmt"
	"time"

	"github.com/fulcrum-io/fulcrum/internal/brain"
	"github.com/fulcrum-io/fulcrum/internal/logging"
	policyv1 "github.com/fulcrum-io/fulcrum/pkg/policy/v1"
	"go.uber.org/zap"
)

// Evaluator provides policy evaluation capabilities.
type Evaluator struct {
	// Configuration
	maxEvaluationTime time.Duration
	enableAuditLog    bool
	semanticJudge     *brain.SemanticJudge
}

// NewEvaluator creates a new policy evaluator.
func NewEvaluator(opts ...EvaluatorOption) *Evaluator {
	e := &Evaluator{
		maxEvaluationTime: 10 * time.Millisecond,
		enableAuditLog:    true,
	}
	for _, opt := range opts {
		opt(e)
	}
	return e
}

type EvaluatorOption func(*Evaluator)

func WithSemanticJudge(judge *brain.SemanticJudge) EvaluatorOption {
	return func(e *Evaluator) {
		e.semanticJudge = judge
	}
}

// EvaluatePolicy evaluates a single policy against the provided context.
func (e *Evaluator) EvaluatePolicy(ctx context.Context, policy *policyv1.Policy, evalCtx *policyv1.EvaluationContext) (*policyv1.EvaluationResult, error) {
	startTime := time.Now()

	// Validate inputs
	if policy == nil {
		return nil, fmt.Errorf("policy is nil")
	}
	if evalCtx == nil {
		return nil, fmt.Errorf("evaluation context is nil")
	}

	// Check if policy is active
	if policy.Status != policyv1.PolicyStatus_POLICY_STATUS_ACTIVE {
		return &policyv1.EvaluationResult{
			PolicyId: policy.PolicyId,
			Decision: policyv1.EvaluationDecision_EVALUATION_DECISION_ALLOW,
			Message:  fmt.Sprintf("Policy %s is not active (status: %s)", policy.PolicyId, policy.Status),
			Context:  evalCtx,
		}, nil
	}

	// Check if policy applies to this context
	if !e.policyApplies(policy, evalCtx) {
		return &policyv1.EvaluationResult{
			PolicyId: policy.PolicyId,
			Decision: policyv1.EvaluationDecision_EVALUATION_DECISION_ALLOW,
			Message:  "Policy does not apply to this context",
			Context:  evalCtx,
		}, nil
	}

	// Evaluate rules in priority order
	var matchedRules []*policyv1.RuleMatch
	var actions []*policyv1.PolicyAction
	decision := policyv1.EvaluationDecision_EVALUATION_DECISION_ALLOW

	for _, rule := range policy.Rules {
		if e.enableAuditLog {
			logging.Debug("evaluating rule",
				zap.String("rule_id", rule.RuleId),
				zap.Bool("enabled", rule.Enabled))
		}
		if !rule.Enabled {
			continue
		}

		// Evaluate all conditions in the rule
		ruleMatches, err := e.evaluateRule(rule, evalCtx)
		if e.enableAuditLog {
			logging.Debug("rule evaluation complete",
				zap.String("rule_id", rule.RuleId),
				zap.Bool("matches", ruleMatches),
				zap.Int("conditions", len(rule.Conditions)),
				logging.Err(err))
		}
		if err != nil {
			if e.enableAuditLog {
				logging.Debug("rule evaluation error",
					zap.String("rule_id", rule.RuleId),
					logging.Err(err))
			}
			continue
		}

		if ruleMatches {
			// Record matched rule
			matchedRules = append(matchedRules, &policyv1.RuleMatch{
				RuleId:   rule.RuleId,
				RuleName: rule.Name,
				Priority: rule.Priority,
			})

			// Collect actions
			actions = append(actions, rule.Actions...)

			// Update decision based on actions
			for _, action := range rule.Actions {
				if action.ActionType == policyv1.ActionType_ACTION_TYPE_DENY {
					decision = policyv1.EvaluationDecision_EVALUATION_DECISION_DENY
				} else if action.ActionType == policyv1.ActionType_ACTION_TYPE_WARN && decision == policyv1.EvaluationDecision_EVALUATION_DECISION_ALLOW {
					decision = policyv1.EvaluationDecision_EVALUATION_DECISION_WARN
				} else if action.ActionType == policyv1.ActionType_ACTION_TYPE_REQUIRE_APPROVAL {
					decision = policyv1.EvaluationDecision_EVALUATION_DECISION_REQUIRE_APPROVAL
				}

				// Stop if terminal action
				if action.Terminal {
					goto evaluationComplete
				}
			}
		}
	}

evaluationComplete:
	duration := time.Since(startTime)

	result := &policyv1.EvaluationResult{
		PolicyId:             policy.PolicyId,
		Decision:             decision,
		MatchedRules:         matchedRules,
		Actions:              actions,
		EvaluationDurationMs: duration.Milliseconds(),
		Context:              evalCtx,
	}

	// Generate message
	if len(matchedRules) == 0 {
		result.Message = "No rules matched"
	} else {
		result.Message = fmt.Sprintf("%d rule(s) matched", len(matchedRules))
	}

	// Audit log
	if e.enableAuditLog {
		logging.Debug("policy evaluated",
			logging.PolicyID(policy.PolicyId),
			zap.Duration("duration", duration),
			zap.String("decision", decision.String()),
			zap.Int("matched_rules", len(matchedRules)))
	}

	// Check if evaluation took too long
	if duration > e.maxEvaluationTime {
		logging.Warn("policy evaluation exceeded time limit",
			zap.Duration("duration", duration),
			zap.Duration("limit", e.maxEvaluationTime))
	}

	return result, nil
}

// EvaluatePolicies evaluates multiple policies against the provided context.
func (e *Evaluator) EvaluatePolicies(ctx context.Context, policies []*policyv1.Policy, evalCtx *policyv1.EvaluationContext, stopOnDeny bool) (*policyv1.EvaluationResult, error) {
	var allResults []*policyv1.EvaluationResult
	var allActions []*policyv1.PolicyAction
	finalDecision := policyv1.EvaluationDecision_EVALUATION_DECISION_ALLOW

	for _, policy := range policies {
		result, err := e.EvaluatePolicy(ctx, policy, evalCtx)
		if err != nil {
			if e.enableAuditLog {
				logging.Debug("policy evaluation error",
					logging.PolicyID(policy.PolicyId),
					logging.Err(err))
			}
			continue
		}

		allResults = append(allResults, result)
		allActions = append(allActions, result.Actions...)

		// Update final decision (DENY takes precedence)
		if result.Decision == policyv1.EvaluationDecision_EVALUATION_DECISION_DENY {
			finalDecision = policyv1.EvaluationDecision_EVALUATION_DECISION_DENY
			if stopOnDeny {
				break
			}
		} else if result.Decision == policyv1.EvaluationDecision_EVALUATION_DECISION_REQUIRE_APPROVAL {
			if finalDecision != policyv1.EvaluationDecision_EVALUATION_DECISION_DENY {
				finalDecision = policyv1.EvaluationDecision_EVALUATION_DECISION_REQUIRE_APPROVAL
			}
		} else if result.Decision == policyv1.EvaluationDecision_EVALUATION_DECISION_WARN {
			if finalDecision == policyv1.EvaluationDecision_EVALUATION_DECISION_ALLOW {
				finalDecision = policyv1.EvaluationDecision_EVALUATION_DECISION_WARN
			}
		}
	}

	// Aggregate results
	var totalMatches int
	for _, r := range allResults {
		totalMatches += len(r.MatchedRules)
	}

	result := &policyv1.EvaluationResult{
		Decision: finalDecision,
		Actions:  allActions,
		Message:  fmt.Sprintf("Evaluated %d policies, %d total rule matches", len(allResults), totalMatches),
		Context:  evalCtx,
	}

	return result, nil
}

// evaluateRule evaluates all conditions in a rule and returns true if all match.
func (e *Evaluator) evaluateRule(rule *policyv1.PolicyRule, ctx *policyv1.EvaluationContext) (bool, error) {
	if len(rule.Conditions) == 0 {
		// Rule with no conditions always matches
		return true, nil
	}

	// All conditions must match (implicit AND)
	for _, condition := range rule.Conditions {
		var matches bool
		var err error

		if condition.ConditionType == policyv1.ConditionType_CONDITION_TYPE_SEMANTIC {
			if e.semanticJudge == nil {
				if e.enableAuditLog {
					logging.Warn("semantic condition without SemanticJudge",
						zap.String("rule_id", rule.RuleId))
				}
				return false, nil // Fail open or closed? Here returning false means rule doesn't match.
			}
			judgeCtx, judgeCancel := context.WithTimeout(context.Background(), 15*time.Second)
			matches, err = e.semanticJudge.Evaluate(judgeCtx, condition, ctx)
			judgeCancel()
		} else {
			matches, err = EvaluateCondition(condition, ctx)
		}

		if err != nil {
			return false, err
		}
		if !matches {
			return false, nil // Short-circuit on first non-match
		}
	}

	return true, nil
}

// policyApplies checks if a policy applies to the given evaluation context.
func (e *Evaluator) policyApplies(policy *policyv1.Policy, ctx *policyv1.EvaluationContext) bool {
	if policy.Scope == nil {
		return true // No scope means applies to everything
	}

	scope := policy.Scope

	// Check if applies to all
	if scope.ApplyToAll {
		return true
	}

	// Check workflow
	if len(scope.WorkflowIds) > 0 {
		found := false
		for _, wf := range scope.WorkflowIds {
			if wf == ctx.WorkflowId {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}

	// Check phase
	if len(scope.Phases) > 0 {
		found := false
		for _, phase := range scope.Phases {
			if phase == ctx.Phase {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}

	// Check roles - O(n) set-based lookup
	if len(scope.Roles) > 0 {
		userRoleSet := make(map[string]struct{}, len(ctx.UserRoles))
		for _, userRole := range ctx.UserRoles {
			userRoleSet[userRole] = struct{}{}
		}
		found := false
		for _, role := range scope.Roles {
			if _, exists := userRoleSet[role]; exists {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}

	// Check models
	if len(scope.ModelIds) > 0 {
		found := false
		for _, model := range scope.ModelIds {
			if model == ctx.ModelId {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}

	// Check tools - O(n) set-based lookup
	if len(scope.ToolNames) > 0 {
		ctxToolSet := make(map[string]struct{}, len(ctx.ToolNames))
		for _, ctxTool := range ctx.ToolNames {
			ctxToolSet[ctxTool] = struct{}{}
		}
		found := false
		for _, tool := range scope.ToolNames {
			if _, exists := ctxToolSet[tool]; exists {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}

	return true
}

// ValidatePolicy validates a policy definition for correctness.
func ValidatePolicy(policy *policyv1.Policy) error {
	if policy == nil {
		return fmt.Errorf("policy is nil")
	}

	if policy.PolicyId == "" {
		return fmt.Errorf("policy_id is required")
	}

	if policy.TenantId == "" {
		return fmt.Errorf("tenant_id is required")
	}

	if len(policy.Rules) == 0 {
		return fmt.Errorf("policy must have at least one rule")
	}

	// Validate each rule
	for i, rule := range policy.Rules {
		if err := validateRule(rule); err != nil {
			return fmt.Errorf("rule %d (%s) invalid: %w", i, rule.RuleId, err)
		}
	}

	return nil
}

// validateRule validates a policy rule for correctness.
func validateRule(rule *policyv1.PolicyRule) error {
	if rule == nil {
		return fmt.Errorf("rule is nil")
	}

	if rule.RuleId == "" {
		return fmt.Errorf("rule_id is required")
	}

	if len(rule.Actions) == 0 {
		return fmt.Errorf("rule must have at least one action")
	}

	// Validate conditions
	for i, condition := range rule.Conditions {
		if err := validateCondition(condition); err != nil {
			return fmt.Errorf("condition %d invalid: %w", i, err)
		}
	}

	return nil
}

// validateCondition validates a condition for correctness.
func validateCondition(condition *policyv1.PolicyCondition) error {
	if condition == nil {
		return fmt.Errorf("condition is nil")
	}

	// Logical conditions must have nested conditions
	if condition.ConditionType == policyv1.ConditionType_CONDITION_TYPE_LOGICAL {
		if len(condition.NestedConditions) == 0 {
			return fmt.Errorf("logical condition must have nested conditions")
		}
		// Recursively validate nested conditions
		for i, nested := range condition.NestedConditions {
			if err := validateCondition(nested); err != nil {
				return fmt.Errorf("nested condition %d invalid: %w", i, err)
			}
		}
		return nil
	}

	// Non-logical conditions must have a field
	if condition.Field == "" {
		return fmt.Errorf("condition field is required")
	}

	// IN/NOT_IN conditions must have values list
	if condition.Operator == policyv1.ConditionOperator_CONDITION_OPERATOR_IN ||
		condition.Operator == policyv1.ConditionOperator_CONDITION_OPERATOR_NOT_IN {
		if len(condition.Values) == 0 {
			return fmt.Errorf("IN/NOT_IN conditions require values list")
		}
	}

	return nil
}
