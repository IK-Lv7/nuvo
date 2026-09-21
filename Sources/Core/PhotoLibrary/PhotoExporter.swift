import Foundation
import Photos

public enum PhotoExporterError: Error, Equatable {
    case notAuthorized
}

/// 写真ライブラリへの保存のみを行う(読み取り権限は要求しない)。
public enum PhotoExporter {
    public static func save(imageData: Data, format: ExportFormat) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoExporterError.notAuthorized
        }
        try await PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            options.uniformTypeIdentifier = format.utiIdentifier
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: imageData, options: options)
        }
    }
}
