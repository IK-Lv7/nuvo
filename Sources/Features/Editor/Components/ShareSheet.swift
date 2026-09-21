import SwiftUI
import UIKit

/// iOS の共有シート。送り先の選択も送信も OS とユーザーが行い、Nuvo は通信しない。
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
