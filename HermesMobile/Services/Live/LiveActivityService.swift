import ActivityKit
import Foundation

/// Manages Hermes Live Activities on the Lock Screen and Dynamic Island.
@MainActor
@Observable
final class LiveActivityService {
    private var currentActivity: Activity<HermesActivityAttributes>?
    private var startedAt: Date?

    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Voice Session

    func startVoiceSession() {
        guard isAvailable else { return }
        let now = Date.now
        let attributes = HermesActivityAttributes(agentName: "Hermes")
        let state = HermesActivityAttributes.ContentState(
            status: "Listening", toolName: nil, elapsedSeconds: 0, startDate: now, sessionType: "voice"
        )
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            startedAt = now
        } catch {
            // Live Activities not supported or disabled — silently ignore
        }
    }

    func updateVoiceState(_ status: String, toolName: String? = nil) {
        let elapsed = Int(Date().timeIntervalSince(startedAt ?? .now))
        let state = HermesActivityAttributes.ContentState(
            status: status, toolName: toolName, elapsedSeconds: elapsed, startDate: startedAt, sessionType: "voice"
        )
        updateActivity(with: state)
    }

    // MARK: - Chat / Tool Calls

    func startToolCall(toolName: String) {
        guard isAvailable, currentActivity == nil else { return }
        let now = Date.now
        let attributes = HermesActivityAttributes(agentName: "Hermes")
        let state = HermesActivityAttributes.ContentState(
            status: "Working...", toolName: toolName, elapsedSeconds: 0, startDate: now, sessionType: "tool"
        )
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            startedAt = now
        } catch {
            // Silently ignore
        }
    }

    func updateToolProgress(_ status: String, toolName: String? = nil) {
        let elapsed = Int(Date().timeIntervalSince(startedAt ?? .now))
        let state = HermesActivityAttributes.ContentState(
            status: status, toolName: toolName, elapsedSeconds: elapsed, startDate: startedAt, sessionType: "tool"
        )
        updateActivity(with: state)
    }

    // MARK: - End

    func endActivity() {
        guard let activity = currentActivity else { return }
        startedAt = nil
        currentActivity = nil

        let finalContent = ActivityContent(
            state: HermesActivityAttributes.ContentState(
                status: "Done", toolName: nil, elapsedSeconds: 0, startDate: nil, sessionType: "voice"
            ),
            staleDate: nil
        )
        let activityID = activity.id
        Task.detached {
            for activity in Activity<HermesActivityAttributes>.activities where activity.id == activityID {
                await activity.end(finalContent, dismissalPolicy: .immediate)
            }
        }
    }

    // MARK: - Private

    private func updateActivity(with state: HermesActivityAttributes.ContentState) {
        guard let activity = currentActivity, activity.activityState == .active else { return }
        let content = ActivityContent(state: state, staleDate: nil)
        let activityID = activity.id
        Task.detached {
            for activity in Activity<HermesActivityAttributes>.activities where activity.id == activityID {
                await activity.update(content)
            }
        }
    }

    // MARK: - App Lifecycle

    /// Called when the app returns to foreground. No timer to restart —
    /// the widget uses Text(timerInterval:) which ticks natively via the OS.
    func handleAppDidBecomeActive() {
        // No-op: Text(timerInterval:) handles the clock without updates.
        // State updates (status, toolName) are pushed when they change.
    }
}
