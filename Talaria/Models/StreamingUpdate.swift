import Foundation

enum StreamingUpdate: Sendable {
    case messageSent(jobID: UUID)
    case textDelta(String)
    case toolActivity(String)
    case finished(Message, TokenUsage?, CodeDiff?)
    case failed(String)
    /// The stream dropped (e.g. the app was backgrounded on lock) AFTER the run
    /// was committed server-side. Not a failure: the run keeps running on the
    /// host and is reconciled via the Sessions messages endpoint.
    case interrupted(sessionId: String, runId: String?)
}
