import SwiftUI

// Small SwiftUI versions of the phone components (components.css), for the host app's own screens.

struct PhoneButton: View {
    enum Kind { case primary, secondary, destructive }
    var title: String
    var kind: Kind = .primary
    var disabledReason: String?
    var action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Text(title).font(NB.PhoneType.body.weight(.heavy))
                    .frame(maxWidth: .infinity, minHeight: NB.phoneActionHeight)
                    .background(background, in: RoundedRectangle(cornerRadius: NB.Radius.md, style: .continuous))
                    .foregroundStyle(kind == .secondary ? NB.Palette.text : .white)
                    .opacity(disabledReason == nil ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(disabledReason != nil)
            if let disabledReason {
                Text(disabledReason).font(NB.PhoneType.caption).foregroundStyle(NB.Palette.textDim)
            }
        }
    }

    private var background: Color {
        switch kind {
        case .primary: NB.Palette.coral
        case .secondary: NB.Palette.inkRaised
        case .destructive: NB.Palette.danger
        }
    }
}

/// A host screen: centred content and a pinned action area.
struct PhoneScreen<Content: View, Action: View>: View {
    var center = true
    @ViewBuilder var content: Content
    @ViewBuilder var action: Action
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: center ? .center : .leading, spacing: 16) { content }
                    .multilineTextAlignment(center ? .center : .leading)
                    .padding(.horizontal, center ? 28 : NB.Space.phoneMargin)
                    .padding(.top, 24)
                    .frame(maxWidth: .infinity, minHeight: center ? 560 : 0, alignment: center ? .center : .topLeading)
            }
            VStack(spacing: 8) { action }
                .padding(.horizontal, NB.Space.phoneMargin)
                .padding(.vertical, 12)
        }
        .foregroundStyle(NB.Palette.text)
        .background(NB.Palette.ink)
    }
}

struct BigIcon: View {
    var glyph: String
    var body: some View {
        Text(glyph).font(.system(size: 48)).frame(width: 96, height: 96)
            .background(NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: 29, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct TVArt: View {
    var glyph: String
    var tint: Color = NB.Palette.inkLine
    var on = false
    var body: some View {
        VStack(spacing: 8) {
            Text(glyph).font(.system(size: 44)).frame(width: 168, height: 104)
                .background(on ? NB.Palette.coral.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(on ? NB.Palette.coral : tint, lineWidth: 6))
            Capsule().fill(NB.Palette.inkLine).frame(width: 60, height: 8)
        }
        .accessibilityHidden(true)
    }
}

extension Text {
    func phoneTitle() -> some View { font(.custom("Nunito", size: 34).weight(.black)) }
    func phoneBodyDim() -> some View { font(NB.PhoneType.body).foregroundStyle(NB.Palette.textDim) }
}
