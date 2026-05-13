import Foundation

/// On-device agentic decisioning facade.
///
/// Where ``NotifiableRemote`` decides _how_ a remote notification reaches the
/// device, `NotifiableDecide` decides _whether_ a candidate alert is
/// worth showing the user and how it should read. The two facades together
/// form NotifiableRemote's intelligent-alerts platform.
///
/// Typical usage:
///
/// ```swift
/// let engine = NotifiableDecide.Engine(
///     store: NotifiableDecide.InMemoryPreferenceStore(),
///     adapter: NotifiableDecide.FoundationModelAdapter()
/// )
///
/// let decision = try await engine.decide(
///     domain: "demo.alerts",
///     candidates: candidates,
///     schema: NotifiableDecide.AlertDecision.self
/// )
/// ```
public enum NotifiableDecide {}
