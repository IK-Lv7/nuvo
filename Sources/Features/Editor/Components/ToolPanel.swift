import NuvoCore
import SwiftUI

/// 選択中のツールの操作部。スライダー1本で済むツールは値を大きく見せ、それ以外は専用の部品を出す。
struct ToolPanel: View {
    let tool: EditorTool
    let viewModel: EditorViewModel
    let lookStore: LookStore
    @Binding var isHealing: Bool
    @Binding var cutoutMode: MaskStroke.Mode
    @Binding var cutoutBrushRadius: Double

    var body: some View {
        switch tool.kind {
        case .slider(let keyPath, let range):
            sliderPanel(keyPath, range)
        case .filters:
            filterPanel
        case .backgroundColor:
            backgroundPanel
        case .idPhoto:
            idPhotoPanel
        case .blemish:
            blemishPanel
        case .autoEnhance:
            autoEnhancePanel
        case .orientation:
            orientationPanel
        case .aspect:
            aspectPanel
        case .text:
            TextToolPanel(viewModel: viewModel)
        case .stamp:
            StampToolPanel(viewModel: viewModel)
        case .looks:
            LooksPanel(viewModel: viewModel, store: lookStore)
        case .people:
            PeopleToolPanel(viewModel: viewModel)
        case .highResolution:
            HighResolutionToolPanel(viewModel: viewModel)
        case .lipstick:
            lipstickPanel
        case .blush:
            blushPanel
        case .eyeshadow:
            eyeshadowPanel
        case .lens:
            lensPanel
        case .cutout:
            cutoutPanel
        }
    }

    private func sliderPanel(_ keyPath: WritableKeyPath<AdjustmentParameters, Double>,
                             _ range: ClosedRange<Double>) -> some View {
        let value = viewModel.value(for: keyPath)
        return VStack(spacing: 4) {
            // 値をダブルタップでゼロに戻せる。
            Text(valueText(value, signed: range.lowerBound < 0))
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .onTapGesture(count: 2) {
                    // 既定値へ戻す(ズームは 0 ではなく 1 倍)。
                    viewModel.setValue(AdjustmentParameters()[keyPath: keyPath], for: keyPath)
                    viewModel.commitEdit()
                }
            TrackSlider(
                value: Binding(get: { viewModel.value(for: keyPath) },
                               set: { viewModel.setValue($0, for: keyPath) }),
                range: range,
                onEditingEnded: { viewModel.commitEdit() })
            if tool.id == "cropZoom" && value > 1 {
                Text("editor.cropZoomHint").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func valueText(_ value: Double, signed: Bool) -> String {
        let percent = Int((value * 100).rounded())
        return signed && percent > 0 ? "+\(percent)" : "\(percent)"
    }

    private var filterPanel: some View {
        VStack(spacing: 8) {
            ChipStrip(items: FilterPreset.allCases, selected: viewModel.parameters.filter,
                      title: { LocalizedStringKey.dynamic("filter." + $0.rawValue) },
                      noneTitle: "filter.none") { viewModel.setFilter($0) }
            if viewModel.parameters.filter != nil {
                TrackSlider(
                    value: Binding(get: { viewModel.value(for: \.filterIntensity) },
                                   set: { viewModel.setValue($0, for: \.filterIntensity) }),
                    range: AdjustmentParameters.intensityRange,
                    onEditingEnded: { viewModel.commitEdit() })
            }
        }
    }

    private var backgroundPanel: some View {
        VStack(spacing: 8) {
            if !viewModel.hasSubjectMask {
                Text("editor.noSubject").font(.footnote).foregroundStyle(.secondary)
            } else if viewModel.hasDepthMask {
                Text("editor.depthUsed").font(.footnote).foregroundStyle(.secondary)
            }
            ChipStrip(items: BackgroundColor.allCases, selected: viewModel.parameters.backgroundColor,
                      title: { LocalizedStringKey.dynamic("background." + $0.rawValue) },
                      noneTitle: "background.none") { color in viewModel.update { $0.backgroundColor = color } }
        }
    }

    private var idPhotoPanel: some View {
        VStack(spacing: 8) {
            ChipStrip(items: IDPhotoSpec.allCases, selected: viewModel.parameters.idPhoto,
                      title: { LocalizedStringKey.dynamic("idPhoto." + $0.rawValue) },
                      noneTitle: "idPhoto.none") { viewModel.setIDPhoto($0) }
            if viewModel.idPhotoUnavailable {
                Text("editor.idPhotoIssue").font(.footnote).foregroundStyle(.orange)
            }
        }
    }

    private var blemishPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button { isHealing.toggle() } label: {
                    Label("editor.tapToHeal", systemImage: "hand.tap")
                }
                .buttonStyle(PillButtonStyle(isOn: isHealing))
                .disabled(viewModel.hasComposition)
                .opacity(viewModel.hasComposition ? 0.5 : 1)
                Button { viewModel.autoRemoveBlemishes() } label: {
                    Label("editor.autoHeal", systemImage: "wand.and.stars")
                }
                .buttonStyle(PillButtonStyle())
            }
            if viewModel.hasComposition {
                Text("editor.healBlockedByComposition").font(.footnote).foregroundStyle(.orange)
            } else if isHealing {
                Text("editor.healHint").font(.footnote).foregroundStyle(.secondary)
            } else if let count = viewModel.autoHealCount {
                Text(count == 0 ? LocalizedStringKey("editor.autoHealNone")
                                : LocalizedStringKey("editor.autoHealDone \(count)"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var lipstickPanel: some View {
        let currentColor = viewModel.parameters.lipstickColor ?? LipstickPreset.rose.tint
        return VStack(spacing: 8) {
            ColorPresetRow(
                presets: LipstickPreset.allCases,
                tint: { $0.tint },
                title: { LocalizedStringKey.dynamic("lipstick." + $0.rawValue) },
                selected: currentColor,
                onSelectPreset: { viewModel.setLipstickColor($0) },
                customBinding: colorPickerBinding(current: currentColor, apply: { viewModel.setLipstickColor($0) }))
            sliderPanel(\.lipstick, AdjustmentParameters.intensityRange)
        }
    }

    private var blushPanel: some View {
        let currentColor = viewModel.parameters.blushColor ?? BlushPreset.pink.tint
        return VStack(spacing: 8) {
            ColorPresetRow(
                presets: BlushPreset.allCases,
                tint: { $0.tint },
                title: { LocalizedStringKey.dynamic("blush." + $0.rawValue) },
                selected: currentColor,
                onSelectPreset: { viewModel.setBlushColor($0) },
                customBinding: colorPickerBinding(current: currentColor, apply: { viewModel.setBlushColor($0) }))
            sliderPanel(\.blush, AdjustmentParameters.intensityRange)
        }
    }

    private var eyeshadowPanel: some View {
        let currentColor = viewModel.parameters.eyeshadowColor ?? EyeshadowPreset.brown.tint
        return VStack(spacing: 8) {
            ColorPresetRow(
                presets: EyeshadowPreset.allCases,
                tint: { $0.tint },
                title: { LocalizedStringKey.dynamic("eyeshadow." + $0.rawValue) },
                selected: currentColor,
                onSelectPreset: { viewModel.setEyeshadowColor($0) },
                customBinding: colorPickerBinding(current: currentColor, apply: { viewModel.setEyeshadowColor($0) }))
            sliderPanel(\.eyeshadow, AdjustmentParameters.intensityRange)
        }
    }

    private var lensPanel: some View {
        let currentColor = viewModel.parameters.lensColor ?? LensPreset.brown.tint
        return VStack(spacing: 8) {
            ColorPresetRow(
                presets: LensPreset.allCases,
                tint: { $0.tint },
                title: { LocalizedStringKey.dynamic("lens." + $0.rawValue) },
                selected: currentColor,
                onSelectPreset: { viewModel.setLensColor($0) },
                customBinding: colorPickerBinding(current: currentColor, apply: { viewModel.setLensColor($0) }))
            sliderPanel(\.lens, AdjustmentParameters.intensityRange)
        }
    }

    private var cutoutPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button { cutoutMode = .keep } label: { Label("cutout.keep", systemImage: "paintbrush.pointed.fill") }
                    .buttonStyle(PillButtonStyle(isOn: cutoutMode == .keep))
                Button { cutoutMode = .erase } label: { Label("cutout.erase", systemImage: "eraser.fill") }
                    .buttonStyle(PillButtonStyle(isOn: cutoutMode == .erase))
                Button { viewModel.clearMaskStrokes() } label: { Label("cutout.reset", systemImage: "arrow.uturn.backward") }
                    .buttonStyle(PillButtonStyle())
                    .disabled(viewModel.parameters.maskStrokes?.isEmpty != false)
                    .opacity(viewModel.parameters.maskStrokes?.isEmpty != false ? 0.5 : 1)
            }
            TrackSlider(value: $cutoutBrushRadius, range: AdjustmentParameters.maskBrushRadiusRange, onEditingEnded: {})
            if !viewModel.hasSubjectMask {
                Text("cutout.noSubject").font(.footnote).foregroundStyle(.secondary)
            } else if viewModel.hasComposition {
                Text("cutout.blockedByComposition").font(.footnote).foregroundStyle(.orange)
            } else {
                Text("cutout.hint").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var autoEnhancePanel: some View {
        Button {
            viewModel.update { $0.autoEnhance.toggle() }
        } label: {
            Label(viewModel.parameters.autoEnhance ? "editor.on" : "editor.off",
                  systemImage: viewModel.parameters.autoEnhance ? "checkmark.circle.fill" : "circle")
        }
        .buttonStyle(PillButtonStyle(isOn: viewModel.parameters.autoEnhance))
    }

    private var orientationPanel: some View {
        HStack(spacing: 10) {
            Button { viewModel.update { $0.rotationQuarterTurns = ($0.rotationQuarterTurns + 3) % 4 } } label: {
                Label("editor.rotateLeft", systemImage: "rotate.left")
            }
            .buttonStyle(PillButtonStyle())
            Button { viewModel.update { $0.rotationQuarterTurns = ($0.rotationQuarterTurns + 1) % 4 } } label: {
                Label("editor.rotateRight", systemImage: "rotate.right")
            }
            .buttonStyle(PillButtonStyle())
            Button { viewModel.update { $0.flipHorizontal.toggle() } } label: {
                Label("editor.flip", systemImage: "arrow.left.and.right")
            }
            .buttonStyle(PillButtonStyle(isOn: viewModel.parameters.flipHorizontal))
        }
    }

    private var aspectPanel: some View {
        ChipStrip(items: CropAspect.allCases, selected: viewModel.parameters.cropAspect,
                  title: { LocalizedStringKey.dynamic("crop." + $0.rawValue) },
                  noneTitle: "crop.none") { aspect in viewModel.update { $0.cropAspect = aspect } }
    }
}

