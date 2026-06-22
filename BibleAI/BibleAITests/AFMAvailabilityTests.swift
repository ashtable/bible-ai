#if canImport(FoundationModels)
import Testing
import FoundationModels

@Suite("Task 0 — AFM availability gate")
struct AFMAvailabilityTests {

    @Test("availability is exhaustively handled, never #available-gated")
    func afmAvailability_isHandledExhaustively() {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            #expect(Bool(true))
        case .unavailable(let reason):
            #expect(!"\(reason)".isEmpty)
        }
    }
}
#endif
