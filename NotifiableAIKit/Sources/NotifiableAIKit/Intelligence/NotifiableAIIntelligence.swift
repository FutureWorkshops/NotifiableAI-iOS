import Foundation

/// On-device agentic decisioning facade.
///
/// Where ``NotifiableAI`` decides _how_ a remote notification reaches the
/// device, `NotifiableAIIntelligence` decides _whether_ a candidate alert is
/// worth showing the user and how it should read. The two facades together
/// form NotifiableAI's intelligent-alerts platform.
///
/// Typical usage:
///
/// ```swift
/// let engine = NotifiableAIIntelligence.Engine(
///     store: NotifiableAIIntelligence.InMemoryPreferenceStore(),
///     adapter: NotifiableAIIntelligence.FoundationModelAdapter()
/// )
///
/// let decision = try await engine.decide(
///     domain: "demo.alerts",
///     candidates: candidates,
///     schema: NotifiableAIIntelligence.AlertDecision.self
/// )
/// ```
public enum NotifiableAIIntelligence {}
