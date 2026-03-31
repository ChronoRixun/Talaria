import SwiftUI

struct GlassCircleButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: Design.Size.iconMedium, weight: .medium))
                .foregroundStyle(.primary)
                .frame(
                    width: Design.Size.glassCircleButton,
                    height: Design.Size.glassCircleButton
                )
        }
        .clipShape(Circle())
        .glassEffect(.regular.interactive(), in: Circle())
    }
}
