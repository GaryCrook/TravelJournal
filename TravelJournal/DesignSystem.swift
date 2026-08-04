import SwiftUI

// MARK: - Design System
//
// Style guide: Dribbble shot 24911825 (TripGlide)
// Font: Instrument Sans (add to project via File → Add Files, then Info.plist)
//       Falls back to SF Pro automatically if the font file isn't bundled yet.
// Colors: #212529 (primary), #f5f6f7 (surface), #ffffff (background)

enum DS {

    // MARK: Colors

    enum Color {
        /// Near-black — primary text, dark buttons  (#212529)
        static let primary   = SwiftUI.Color(hex: "212529")
        /// Mid-gray — secondary text, placeholders  (#888888)
        static let secondary = SwiftUI.Color(hex: "888888")
        /// Off-white — card / input backgrounds  (#f5f6f7)
        static let surface   = SwiftUI.Color(hex: "f5f6f7")
        /// Pure white — screen background
        static let background = SwiftUI.Color.white
        /// Subtle border
        static let border    = SwiftUI.Color(hex: "E8E8E8")
    }

    // MARK: Typography
    //
    // Uses Instrument Sans when bundled; falls back to SF Pro seamlessly.

    enum Font {
        static let display   = instrumentSans(size: 32, weight: .bold)
        static let headline  = instrumentSans(size: 26, weight: .bold)
        static let title     = instrumentSans(size: 20, weight: .bold)
        static let title2    = instrumentSans(size: 18, weight: .semibold)
        static let body      = instrumentSans(size: 15, weight: .regular)
        static let callout   = instrumentSans(size: 14, weight: .medium)
        static let caption   = instrumentSans(size: 13, weight: .regular)
        static let label     = instrumentSans(size: 11, weight: .medium)

        private static func instrumentSans(size: CGFloat, weight: SwiftUI.Font.Weight) -> SwiftUI.Font {
            let name: String
            switch weight {
            case .bold:       name = "InstrumentSans-Bold"
            case .semibold:   name = "InstrumentSans-SemiBold"
            case .medium:     name = "InstrumentSans-Medium"
            default:          name = "InstrumentSans-Regular"
            }
            // If the font isn't bundled, UIFont returns nil and SwiftUI
            // automatically falls back to the system font at the same size.
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
            return .system(size: size, weight: weight, design: .default)
        }
    }

    // MARK: Corner Radii

    enum Radius {
        static let card:   CGFloat = 20
        static let medium: CGFloat = 14
        static let small:  CGFloat = 10
        static let pill:   CGFloat = 100
    }

    // MARK: Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let screen: CGFloat = 20   // standard horizontal screen padding
    }

    // MARK: Shadows

    enum Shadow {
        static func card(opacity: Double = 0.10) -> some View {
            Rectangle()
                .shadow(color: .black.opacity(opacity), radius: 12, x: 0, y: 6)
        }
    }
}

// MARK: - Hex Color Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:  (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB,
                  red:   Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255)
    }
}

// MARK: - Reusable DS Components

/// Pill-shaped filter button matching the style guide
struct DSFilterPill: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DS.Font.callout)
                .foregroundStyle(selected ? .white : DS.Color.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(selected ? DS.Color.primary : DS.Color.surface)
                .clipShape(Capsule())
        }
        .animation(.easeInOut(duration: 0.18), value: selected)
    }
}

/// Dark rounded CTA button
struct DSPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Font.callout)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DS.Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
        }
    }
}

/// Icon button — circle with #f5f6f7 background
struct DSIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 44, height: 44)
                .background(DS.Color.surface)
                .foregroundStyle(DS.Color.primary)
                .clipShape(Circle())
        }
    }
}
