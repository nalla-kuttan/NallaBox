import SwiftUI
import NallaCore

/// M5: room settings sheet.
struct M5SettingsSheet: View {
    @Bindable var model: HostModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Room settings").font(.custom("Nunito", size: 18).weight(.black))
            Toggle(isOn: $model.prefs.familyFriendly) {
                VStack(alignment: .leading) {
                    Text("Family-friendly").font(.custom("Nunito", size: 15).weight(.heavy))
                    Text("Safe prompts and a profanity filter").font(.custom("Nunito", size: 12).weight(.bold)).foregroundStyle(NB.Palette.textDim)
                }
            }
            .toggleStyle(.switch).tint(NB.Palette.coral)
            Text("Default timer speed").font(.custom("Nunito", size: 11).weight(.heavy)).textCase(.uppercase).foregroundStyle(NB.Palette.textDim)
            Picker("Default timer speed", selection: $model.prefs.timer) {
                Text("1×").tag(TimerSpeed.x1); Text("1.5×").tag(TimerSpeed.x15); Text("2×").tag(TimerSpeed.x2); Text("Off").tag(TimerSpeed.off)
            }
            .pickerStyle(.segmented).labelsHidden()
            Toggle(isOn: $model.prefs.voiceOn) {
                VStack(alignment: .leading) {
                    Text("Host voice").font(.custom("Nunito", size: 15).weight(.heavy))
                    Text("Reads prompts aloud. Captions always show.").font(.custom("Nunito", size: 12).weight(.bold)).foregroundStyle(NB.Palette.textDim)
                }
            }
            .toggleStyle(.switch).tint(NB.Palette.coral)
            Text("Caption size").font(.custom("Nunito", size: 11).weight(.heavy)).textCase(.uppercase).foregroundStyle(NB.Palette.textDim)
            Picker("Caption size", selection: $model.prefs.captions) {
                ForEach(CaptionSize.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction).tint(NB.Palette.coral).buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 480)
        .foregroundStyle(NB.Palette.text)
        .background(NB.Palette.inkRaised)
    }
}
