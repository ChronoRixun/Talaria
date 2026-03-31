import SwiftUI

// MARK: - Design Tokens
// All visual constants for HermesMobile. No magic numbers in view code.
// Warm cream/beige palette with Liquid Glass throughout.

enum Design {

    // MARK: - Brand

    enum Brand {
        static let accent = Color("BrandAccent", bundle: nil)
        static let warmCream = Color(red: 0.98, green: 0.97, blue: 0.95)
        static let warmBeige = Color(red: 0.96, green: 0.94, blue: 0.90)
        static let warmGold = Color(red: 0.82, green: 0.68, blue: 0.42)
        static let hermesCharcoal = Color(red: 0.25, green: 0.23, blue: 0.21)
        static let hermesBrown = Color(red: 0.40, green: 0.35, blue: 0.28)

        // Light mode background
        static let backgroundPrimary = Color(red: 0.98, green: 0.97, blue: 0.94)
        static let backgroundSecondary = Color(red: 0.96, green: 0.94, blue: 0.91)

        // Dark mode background (warm dark, not pure black)
        static let darkBackground = Color(red: 0.12, green: 0.11, blue: 0.10)
        static let darkSurface = Color(red: 0.18, green: 0.16, blue: 0.14)
    }

    // MARK: - Spacing (4pt base grid)

    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }

    // MARK: - Corner Radii

    enum CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
        static let full: CGFloat = .infinity
    }

    // MARK: - Typography

    enum Typography {
        static let heroTitle: Font = .largeTitle.bold()
        static let screenTitle: Font = .title.bold()
        static let screenTitle2: Font = .title2.bold()
        static let sectionTitle: Font = .title3.bold()
        static let headline: Font = .headline
        static let body: Font = .body
        static let callout: Font = .callout
        static let footnote: Font = .footnote
        static let caption: Font = .caption
        static let caption2: Font = .caption2
    }

    // MARK: - Animation

    enum Motion {
        static let quickResponse: Animation = .spring(response: 0.25, dampingFraction: 0.8)
        static let standard: Animation = .spring(response: 0.35, dampingFraction: 0.75)
        static let expressive: Animation = .spring(response: 0.5, dampingFraction: 0.7)
        static let gentle: Animation = .spring(response: 0.6, dampingFraction: 0.85)
        static let pulse: Animation = .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
        static let breathe: Animation = .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    }

    // MARK: - Size

    enum Size {
        static let minTapTarget: CGFloat = 44
        static let iconTiny: CGFloat = 10
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 24
        static let iconLarge: CGFloat = 32
        static let iconXL: CGFloat = 40
        static let iconHero: CGFloat = 60
        static let avatarSmall: CGFloat = 32
        static let avatarMedium: CGFloat = 48
        static let avatarLarge: CGFloat = 80
        static let thumbnailSmall: CGFloat = 64
        static let thumbnailMedium: CGFloat = 120
        static let thumbnailLarge: CGFloat = 200
        static let heroHeight: CGFloat = 300
        static let cardMinHeight: CGFloat = 160
        static let badgeSize: CGFloat = 22
        static let inputBarHeight: CGFloat = 52
        static let voiceOrbSize: CGFloat = 200
        static let glassCircleButton: CGFloat = 40
    }
}
