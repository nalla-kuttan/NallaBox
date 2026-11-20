import SwiftUI
import NallaCore

// Insider Trading TV screens I1–I6, ported from design/mockups/_build/pages_insider.py.

enum InsiderTV {
    @MainActor static func view(for tv: TVView) -> AnyView? {
        let d = tv.screen.data
        switch tv.screen.screen {
        case "I1": return (try? d.decode(I1TV.self)).map { AnyView(QuestionScreen(tv: tv, data: $0, foot: ("Check your phone for your role", "Hold the card so no one else sees it"))) }
        case "I2": return (try? d.decode(I1TV.self)).map { AnyView(QuestionScreen(tv: tv, data: $0, foot: ("Talk it out. Betting opens next.", "Insider: steer them, don't get caught"))) }
        case "I3": return (try? d.decode(I3TV.self)).map { AnyView(I3Screen(tv: tv, data: $0)) }
        case "I4": return (try? d.decode(I4TV.self)).map { AnyView(I4Screen(tv: tv, data: $0)) }
        case "I5": return (try? d.decode(I5TV.self)).map { AnyView(I5Screen(tv: tv, data: $0)) }
        case "I6": return (try? d.decode(I6TV.self)).map { AnyView(I6Screen(tv: tv, data: $0)) }
        default: return nil
        }
    }
    static let keys = ["A", "B", "C", "D"]
}

private struct InsiderTop: View {
    var tv: TVView
    var label: String
    var body: some View {
        TVTop {
            TVText.label(label).foregroundStyle(NB.Palette.textDim)
        } right: {
            if let d = tv.screen.deadline { TVTimer(deadline: d) }
            FaceCorner(cue: tv.face)
        }
    }
}

private struct ChoiceTile: View {
    var key: String
    var text: String
    var correct = false
    var dim = false
    var bets: [BetLine] = []
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            Text(key).font(NB.TVType.heading.weight(.black))
                .frame(width: 78, height: 78)
                .background(correct ? NB.Palette.ink.opacity(0.25) : NB.Palette.inkLine, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
            VStack(alignment: .leading, spacing: 12) {
                Text(text).font(NB.TVType.heading).lineLimit(2)
                if !bets.isEmpty {
                    FlowRow(bets: bets)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(correct ? NB.Palette.coral : NB.Palette.inkRaised, in: RoundedRectangle(cornerRadius: NB.Radius.lg, style: .continuous))
        .opacity(dim ? 0.55 : 1)
        .foregroundStyle(NB.Palette.text)
    }
}

private struct FlowRow: View {
    var bets: [BetLine]
    var body: some View {
        HStack(spacing: 10) {
            ForEach(bets, id: \.player.id) { b in
                HStack(spacing: 8) {
                    TVAvatar(name: b.player.name, colour: b.player.colour, size: 40)
                    Text((b.won ? "+" : "−") + grouped(b.chips)).font(.custom("Nunito", size: 30).weight(.heavy))
                }
                .padding(.leading, 4).padding(.trailing, 12).padding(.vertical, 4)
                .background(NB.Palette.ink.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private func choiceGrid(_ choices: [String], answer: Int? = nil, bets: [BetLine] = []) -> some View {
    Grid(horizontalSpacing: 24, verticalSpacing: 24) {
        ForEach(0..<2, id: \.self) { row in
            GridRow {
                ForEach(0..<2, id: \.self) { col in
                    let i = row * 2 + col
                    if i < choices.count {
                        ChoiceTile(key: InsiderTV.keys[i], text: choices[i], correct: answer == i, dim: answer != nil && answer != i,
                                   bets: bets.filter { $0.choice == i })
                    }
                }
            }
        }
    }
}

struct QuestionScreen: View {
    var tv: TVView
    var data: I1TV
    var foot: (String, String)
    var body: some View {
        TVSafe {
            InsiderTop(tv: tv, label: data.top)
            Text(data.question).font(NB.TVType.title).lineSpacing(6).fixedSize(horizontal: false, vertical: true)
            choiceGrid(data.choices)
            Spacer(minLength: 0)
            TVFoot(left: foot.0, right: foot.1)
        }
    }
}

private func waitingGrid(_ players: [PlayerSummary], done: [PlayerID]) -> some View {
    Grid(horizontalSpacing: 16, verticalSpacing: 16) {
        ForEach(Array(stride(from: 0, to: players.count, by: 4)), id: \.self) { start in
            GridRow {
                ForEach(players[start..<min(start + 4, players.count)]) { p in
                    TVChip(player: p, submitted: done.contains(p.id), offline: !p.connected, avatar: 52, font: .custom("Nunito", size: 36), vPad: 12)
                }
            }
        }
    }
}

struct I3Screen: View {
    var tv: TVView
    var data: I3TV
    var body: some View {
        let waiting = data.players.filter { !data.done.contains($0.id) }.count
        TVSafe {
            InsiderTop(tv: tv, label: data.top)
            Text(data.question).font(NB.TVType.title).fixedSize(horizontal: false, vertical: true)
            Text("Place your bets: 100 to 1,000 chips").font(NB.TVType.heading)
            VStack(alignment: .leading, spacing: 20) {
                TVText.label(waiting == 0 ? "Everyone's in" : "Waiting on \(waiting) player\(waiting == 1 ? "" : "s")").foregroundStyle(NB.Palette.textDim)
                waitingGrid(data.players, done: data.done)
            }
            Spacer(minLength: 0)
        }
    }
}

struct I4Screen: View {
    var tv: TVView
    var data: I4TV
    var body: some View {
        TVSafe {
            InsiderTop(tv: tv, label: data.top)
            Text(data.question).font(NB.TVType.title).fixedSize(horizontal: false, vertical: true)
            choiceGrid(data.choices, answer: data.answer, bets: data.bets)
            Spacer(minLength: 0)
            TVFoot(left: "Right answers win their bet. Wrong answers lose it.", right: "Next: find the Insider")
        }
    }
}

struct I5Screen: View {
    var tv: TVView
    var data: I5TV
    var body: some View {
        TVSafe {
            InsiderTop(tv: tv, label: data.top)
            Text("Who was the Insider?").font(.custom("Nunito", size: 96).weight(.black))
            Text("Vote on your phone. A majority unmasks them.").font(NB.TVType.heading).foregroundStyle(NB.Palette.textDim)
            VStack(alignment: .leading, spacing: 20) {
                TVText.label("\(data.voted.count) of \(data.players.count) voted").foregroundStyle(NB.Palette.textDim)
                waitingGrid(data.players, done: data.voted)
            }
            Spacer(minLength: 0)
        }
    }
}

struct I6Screen: View {
    var tv: TVView
    var data: I6TV
    var body: some View {
        TVSafe {
            InsiderTop(tv: tv, label: data.top)
            HStack(alignment: .top, spacing: 80) {
                VStack(alignment: .leading, spacing: 24) {
                    TVAvatar(name: data.insider.name, colour: data.insider.colour, size: 144)
                    Text(data.caught ? "Caught!" : "Escaped!").font(.custom("Nunito", size: 96).weight(.black))
                    Text("\(data.insider.name) was the Insider").font(NB.TVType.title).lineLimit(2).minimumScaleFactor(0.7)
                    Text(data.caught
                         ? "\(data.accusers) of \(data.voters) named them. They pay \(data.penalty) chips to each accuser and lose their cut."
                         : "Only \(data.accusers) of \(data.voters) named them. They keep 10% of the Traders' winnings: +\(grouped(data.commission)) chips.")
                        .font(NB.TVType.heading).foregroundStyle(NB.Palette.textDim).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                TVLeaderboard(standings: data.standings, compact: true).frame(maxWidth: .infinity)
            }
            Spacer(minLength: 0)
        }
    }
}
