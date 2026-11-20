import SwiftUI
import NallaCore

// SwiftUI ports of the mockup components (design/mockups/shared/components.css), TV sizes.

extension PlayerColour {
    var color: Color { NB.PlayerColor(rawValue: rawValue)?.color ?? NB.Palette.inkLine }
}

extension String {
    /// First grapheme, for avatar initials.
    var initial: String { first.map(String.init) ?? "?" }
}

/// "1,500" without the device locale (matches the engine and controller).
func tvNumber(_ n: Int) -> String { grouped(n) }

enum TVText {
    static func label(_ s: String) -> some View {
        Text(s).font(NB.TVType.label).textCase(.uppercase).tracking(NB.TVType.labelTracking)
    }
}

struct TVAvatar: View {
    var name: String
    var colour: PlayerColour
    var size: CGFloat = 72
    var dimmed = false
    var body: some View {
        Text(name.initial)
            .font(.custom("Nunito", size: size * 0.5).weight(.black))
            .foregroundStyle(NB.Palette.ink)
            .frame(width: size, height: size)
            .background(colour.color, in: RoundedRectangle(cornerRadius: NB.Radius.avatar(size), style: .continuous))
            .saturation(dimmed ? 0 : 1)
            .accessibilityHidden(true)
    }
}

struct TVChip: View {
    var player: PlayerSummary
    var leader = false
    var submitted = false
    var offline = false
    var avatar: CGFloat = 72
    var font: Font = NB.TVType.body
    var vPad: CGFloat = 17
    var body: some View {
        HStack(spacing: 19) {
            TVAvatar(name: player.name, colour: player.colour, size: avatar, dimmed: offline)
            Text(player.name).font(font.weight(.heavy)).lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if leader {
                Text("Leader").font(NB.TVType.label.weight(.black)).textCase(.uppercase).tracking(1)
                    .padding(.horizontal, 16).padding(.vertical, 5)
                    .background(NB.Palette.coral, in: RoundedRectangle(cornerRadius: NB.Radius.sm))
                    .foregroundStyle(.white)
            }
            if submitted { Text("✓").font(font.weight(.black)).foregroundStyle(NB.Palette.success) }
            if offline { TVText.label("offline").foregroundStyle(NB.Palette.textDim) }
        }
        .padding(.leading, 17).padding(.trailing, 28).padding(.vertical, vPad)
        .background(submitted ? Color(hex: 0x24303A) : NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: NB.Radius.lg, style: .continuous))
        .overlay { if leader { RoundedRectangle(cornerRadius: NB.Radius.lg, style: .continuous).strokeBorder(NB.Palette.coral, lineWidth: 3) } }
        .opacity(offline ? 0.55 : 1)
        .foregroundStyle(NB.Palette.text)
        .accessibilityElement(children: .combine)
    }
}

struct TVSeat: View {
    var height: CGFloat = 72 + 34
    var body: some View {
        Text("Waiting…").font(NB.TVType.body).foregroundStyle(NB.Palette.textDim)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
            .padding(.horizontal, 28)
            .overlay(RoundedRectangle(cornerRadius: NB.Radius.lg, style: .continuous)
                .strokeBorder(NB.Palette.inkLine, style: StrokeStyle(lineWidth: 3, dash: [10, 8])))
    }
}

/// Countdown from a host-clock deadline (seconds since 1970).
struct TVTimer: View {
    var deadline: Double
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
            let s = max(0, Int((deadline - ctx.date.timeIntervalSince1970).rounded(.up)))
            Text("\(s / 60):\(String(format: "%02d", s % 60))")
                .font(NB.TVType.heading.weight(.black)).monospacedDigit()
                .lineLimit(1).fixedSize()
                .foregroundStyle(.white)
                .padding(.horizontal, 31).padding(.vertical, 10)
                .frame(minWidth: 166)
                .background(s <= 10 ? NB.Palette.coralPress : NB.Palette.coral, in: Capsule())
                .accessibilityLabel("\(s) seconds left")
        }
    }
}

/// Progress bar that empties as `deadline` approaches.
struct TVProgress: View {
    var deadline: Double
    var total: Double
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
            let f = max(0, min(1, (deadline - ctx.date.timeIntervalSince1970) / total))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(NB.Palette.inkLine)
                    Capsule().fill(NB.Palette.coral).frame(width: g.size.width * f)
                }
            }
            .frame(height: 12)
        }
    }
}

struct TVBrand: View {
    var label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                Image("Symbol").resizable().frame(width: 56, height: 56)
                Text("nallabox").font(NB.TVType.label.weight(.black))
            }
            if !label.isEmpty { TVText.label(label).foregroundStyle(NB.Palette.textDim) }
        }
    }
}

/// The 80-pt safe area column every TV screen lives in.
struct TVSafe<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 48) { content }
            .padding(NB.tvSafeInset)
            .frame(width: NB.tvCanvas.width, height: NB.tvCanvas.height, alignment: .topLeading)
            .foregroundStyle(NB.Palette.text)
    }
}

struct TVTop<Left: View, Right: View>: View {
    @ViewBuilder var left: Left
    @ViewBuilder var right: Right
    var body: some View {
        HStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 8) { left }
            Spacer(minLength: 0)
            HStack(spacing: 32) { right }
        }
        .frame(minHeight: NB.faceSize)
    }
}

struct TVFoot: View {
    var left: String
    var right: String = ""
    var body: some View {
        HStack {
            Text(left)
            Spacer()
            Text(right)
        }
        .font(NB.TVType.caption).foregroundStyle(NB.Palette.textDim)
    }
}

struct TVPanel<Content: View>: View {
    var radius: CGFloat = NB.Radius.xl
    var padding: CGFloat = 48
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 24) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct TVBigIcon: View {
    var glyph: String
    var size: CGFloat = 160
    var body: some View {
        Text(glyph).font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(NB.Palette.ink, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

struct TVLeaderboard: View {
    var standings: [Standing]
    var compact = false
    var body: some View {
        VStack(spacing: compact ? 10 : 14) {
            ForEach(standings, id: \.player.id) { s in
                HStack(spacing: 24) {
                    Text("\(s.rank)").font(NB.TVType.body.weight(.black)).foregroundStyle(NB.Palette.textDim).frame(width: 64)
                    TVAvatar(name: s.player.name, colour: s.player.colour, size: compact ? 56 : 72)
                    Text(s.player.name).font(NB.TVType.body.weight(.heavy)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    Text(s.delta == 0 ? "±0" : signed(s.delta)).font(NB.TVType.body.weight(.black)).monospacedDigit()
                        .foregroundStyle(s.delta == 0 ? NB.Palette.textDim : s.delta > 0 ? NB.Palette.success : NB.Palette.danger)
                    Text(tvNumber(s.points)).font(NB.TVType.body.weight(.black)).monospacedDigit().frame(minWidth: 168, alignment: .trailing)
                }
                .padding(.horizontal, 20).padding(.vertical, compact ? 10 : 10)
                .background(NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: NB.Radius.lg, style: .continuous))
            }
        }
    }
}

/// Lays out views in a fixed number of equal columns.
struct TVGrid<Item: Identifiable, Cell: View>: View {
    var items: [Item]
    var columns: Int
    var hSpacing: CGFloat = 24
    var vSpacing: CGFloat = 20
    @ViewBuilder var cell: (Item) -> Cell
    var body: some View {
        Grid(horizontalSpacing: hSpacing, verticalSpacing: vSpacing) {
            ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { start in
                GridRow {
                    ForEach(items[start..<min(start + columns, items.count)]) { cell($0) }
                    if items.count - start < columns {
                        ForEach(0..<(columns - (items.count - start)), id: \.self) { _ in Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]) }
                    }
                }
            }
        }
    }
}

extension PlayerSummary: @retroactive Identifiable {}
extension Standing: @retroactive Identifiable { public var id: PlayerID { player.id } }
