import SwiftUI

struct MessageBubble: View {
    let message: Message

    private var isUser: Bool { message.sender == .user }

    var body: some View {
        HStack(alignment: .top, spacing: Design.Spacing.xs) {
            if isUser {
                Spacer(minLength: Design.Spacing.xxl)
                userBubble
            } else {
                hermesMessage
                Spacer(minLength: Design.Spacing.xxl)
            }
        }
        .padding(.horizontal, Design.Spacing.md)
    }

    // MARK: - User Bubble (frosted glass)

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: Design.Spacing.xxs) {
            Text(message.content)
                .font(Design.Typography.body)
                .foregroundStyle(.primary)
                .padding(.horizontal, Design.Spacing.md)
                .padding(.vertical, Design.Spacing.sm)
                .glassEffect(.regular, in: .rect(cornerRadius: Design.CornerRadius.xl))

            HStack(spacing: Design.Spacing.xxs) {
                Text(message.timestamp, style: .time)
                    .font(Design.Typography.caption2)
                    .foregroundStyle(.tertiary)

                Image(systemName: message.status.displayIcon)
                    .font(.system(size: Design.Size.iconTiny))
                    .foregroundStyle(message.status.displayColor)
                    .accessibilityLabel(message.status.rawValue)
            }
        }
    }

    // MARK: - Hermes Message (plain text with avatar)

    private var hermesMessage: some View {
        HStack(alignment: .top, spacing: Design.Spacing.xs) {
            HermesAvatar(size: Design.Size.avatarSmall)

            VStack(alignment: .leading, spacing: Design.Spacing.xxs) {
                Text(message.content)
                    .font(Design.Typography.body)
                    .foregroundStyle(.primary)
                    .padding(.vertical, Design.Spacing.xxs)

                Text(message.timestamp, style: .time)
                    .font(Design.Typography.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
