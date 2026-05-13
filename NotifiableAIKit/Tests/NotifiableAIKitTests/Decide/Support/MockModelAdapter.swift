import Foundation
@testable import NotifiableAIKit

/// Deterministic in-memory adapter for `decide` tests.
///
/// Either canned `Data` returned to the decoder, or a typed `AlertDecision`
/// that bypasses decoding. Records every call's `systemPrompt` and
/// `contextBlock` so tests can assert on what reached the model.
actor MockModelAdapterStorage {
    enum Response: Sendable {
        case alertDecision(NotifiableDecide.AlertDecision)
        case raw(Data)
        case error(Error)
    }

    private var response: Response
    private(set) var capturedSystemPrompt: String?
    private(set) var capturedContextBlock: String?
    private(set) var callCount: Int = 0

    init(_ response: Response) {
        self.response = response
    }

    func set(_ r: Response) { response = r }

    func handle(systemPrompt: String, contextBlock: String) -> Response {
        capturedSystemPrompt = systemPrompt
        capturedContextBlock = contextBlock
        callCount += 1
        return response
    }
}

final class MockModelAdapter: NotifiableDecide.ModelAdapter, Sendable {
    let storage: MockModelAdapterStorage

    init(_ response: MockModelAdapterStorage.Response) {
        self.storage = MockModelAdapterStorage(response)
    }

    func decide<Schema>(
        systemPrompt: String,
        contextBlock: String,
        schema: Schema.Type,
        options: NotifiableDecide.ModelOptions
    ) async throws -> Schema where Schema: Decodable & Sendable {
        let response = await storage.handle(systemPrompt: systemPrompt, contextBlock: contextBlock)
        switch response {
        case .alertDecision(let decision):
            // Safe force-cast: tests only use this branch when Schema == AlertDecision.
            return decision as! Schema
        case .raw(let data):
            return try JSONDecoder().decode(Schema.self, from: data)
        case .error(let error):
            throw error
        }
    }

    var capturedSystemPrompt: String? {
        get async { await storage.capturedSystemPrompt }
    }
    var capturedContextBlock: String? {
        get async { await storage.capturedContextBlock }
    }
    var callCount: Int {
        get async { await storage.callCount }
    }
}
