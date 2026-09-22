import NuvoCore
import SwiftUI

/// 「加工する人」の操作部。写真に何人写っていて、そのうち何人を加工するかを示す。
/// 顔のタップ・囲みは写真の上(PeopleOverlay)で行うので、ここは状況の表示と「全員」に戻す操作だけ。
struct PeopleToolPanel: View {
    let viewModel: EditorViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text("people.summary \(viewModel.selectedFaces.count) \(viewModel.detectedFaces.count)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Button { viewModel.selectAllFaces() } label: {
                    Label("people.all", systemImage: "person.2.fill")
                }
                .buttonStyle(PillButtonStyle())
                .disabled(viewModel.parameters.excludedFaces.isEmpty)
                .opacity(viewModel.parameters.excludedFaces.isEmpty ? 0.5 : 1)
            }
            if viewModel.hasComposition {
                Text("people.blockedByComposition").font(.footnote).foregroundStyle(.orange)
            } else {
                Text("people.hint").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

/// 「高画質化」の操作部。入り切りと、書き出しが重くなる旨の注意だけ。
struct HighResolutionToolPanel: View {
    let viewModel: EditorViewModel

    private var isOn: Bool { viewModel.parameters.highResolution == true }

    var body: some View {
        VStack(spacing: 8) {
            Button {
                viewModel.update { $0.highResolution = !($0.highResolution == true) }
            } label: {
                Label(isOn ? "editor.on" : "editor.off",
                      systemImage: isOn ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(PillButtonStyle(isOn: isOn))
            Text("highResolution.hint").font(.footnote).foregroundStyle(.secondary)
        }
    }
}
