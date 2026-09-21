import SwiftUI

/// 選択中のカテゴリに属するツールの一覧。変更済みのツールには印を付ける。
struct ToolStrip: View {
    let tools: [EditorTool]
    @Binding var selectedID: String
    let isModified: (EditorTool) -> Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(tools) { tool in
                    Button { selectedID = tool.id } label: { button(tool) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
        }
    }

    private func button(_ tool: EditorTool) -> some View {
        let isSelected = tool.id == selectedID
        return VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: tool.icon)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 52, height: 52)
                    .background {
                        Circle().fill(isSelected ? AnyShapeStyle(Theme.brandGradient)
                                                 : AnyShapeStyle(Color.white.opacity(0.09)))
                    }
                    .foregroundStyle(Color.white)
                if isModified(tool) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Theme.canvas, lineWidth: 2))
                }
            }
            Text(tool.title)
                .font(.caption2)
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
        }
    }
}

/// 画面下部のカテゴリ切り替え。
struct CategoryBar: View {
    let categories: [ToolCategory]
    @Binding var selectedID: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories) { category in
                    let isSelected = category.id == selectedID
                    Button { selectedID = category.id } label: {
                        VStack(spacing: 4) {
                            Image(systemName: category.icon).font(.system(size: 19))
                            Text(category.title).font(.caption2)
                        }
                        .frame(width: 64, height: 48)
                        .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
        }
        .padding(.bottom, 4)
    }
}
