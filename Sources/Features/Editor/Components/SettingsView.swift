import NuvoCore
import SwiftUI

/// 設定。書き出しの扱いと、プライバシーの説明。
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.stripLocationKey) private var stripLocation = true
    @AppStorage(AppSettings.exportFormatKey) private var formatRaw = ExportFormat.jpeg.rawValue
    @AppStorage(AppSettings.exportQualityKey) private var quality = ImageRenderer.defaultQuality

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("settings.format", selection: $formatRaw) {
                        ForEach(ExportFormat.allCases, id: \.rawValue) { format in
                            Text(LocalizedStringKey("settings.format.\(format.rawValue)")).tag(format.rawValue)
                        }
                    }
                    if ExportFormat(rawValue: formatRaw)?.isLossy ?? true {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("settings.quality")
                                Spacer()
                                Text(Int((quality * 100).rounded()), format: .number).monospacedDigit().foregroundStyle(.secondary)
                            }
                            Slider(value: $quality, in: 0.5...1, step: 0.05)
                        }
                    }
                    Toggle("settings.stripLocation", isOn: $stripLocation)
                } header: {
                    Text("settings.export")
                } footer: {
                    Text("settings.exportFooter")
                }
                Section {
                    Text("settings.privacyBody")
                } header: {
                    Text("settings.privacy")
                }
                Section {
                    LabeledContent("settings.version", value: version)
                } header: {
                    Text("settings.about")
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("settings.done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
