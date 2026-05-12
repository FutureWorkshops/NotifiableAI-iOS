import Foundation

/// On-device agentic decisioning facade.
///
/// Where ``NotifiableAI`` decides _how_ a remote notification reaches the
/// device, `NotifiableIntelligence` decides _whether_ a candidate alert is
/// worth showing the user and how it should read. The two facades together
/// form NotifiableAI's intelligent-alerts platform.
///
/// Typical usage:
///
/// ```swift
/// let engine = NotifiableIntelligence.Engine(
///     store: NotifiableIntelligence.InMemoryPreferenceStore(),
///     adapter: NotifiableIntelligence.FoundationModelAdapter()
/// )
///
/// let decision = try await engine.decide(
///     domain: "demo.alerts",
///     candidates: candidates,
///     schema: NotifiableIntelligence.AlertDecision.self
/// )
/// ```
public enum NotifiableIntelligence {}
