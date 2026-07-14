import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    GalleryMethodCallHandler.register(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

// MARK: - Gallery MethodChannel (paridade com Android MainActivity.kt)

private final class GalleryMethodCallHandler: NSObject {
  private static let channelName = "br.com.monitore.app/gallery"

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let handler = GalleryMethodCallHandler()
    channel.setMethodCallHandler { call, result in
      handler.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "saveImageToGallery":
      guard let args = call.arguments as? [String: Any],
            let bytes = args["bytes"] as? FlutterStandardTypedData else {
        result(["success": false, "message": "Bytes da imagem vazios"])
        return
      }
      let fileName = (args["fileName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "photo_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
      saveImageBytes(bytes.data, fileName: fileName, result: result)

    case "saveImageFromFile":
      guard let args = call.arguments as? [String: Any],
            let filePath = args["filePath"] as? String, !filePath.isEmpty else {
        result(["success": false, "message": "Caminho do arquivo vazio"])
        return
      }
      let fileName = (args["fileName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? URL(fileURLWithPath: filePath).lastPathComponent
      guard let data = FileManager.default.contents(atPath: filePath) else {
        result(["success": false, "message": "Arquivo não encontrado: \(filePath)"])
        return
      }
      saveImageBytes(data, fileName: fileName, result: result)

    case "saveJsonToDocuments":
      guard let args = call.arguments as? [String: Any],
            let jsonContent = args["jsonContent"] as? String, !jsonContent.isEmpty else {
        result(["success": false, "message": "Conteudo JSON vazio"])
        return
      }
      var fileName = (args["fileName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "planejamento_\(Int(Date().timeIntervalSince1970 * 1000)).json"
      if !fileName.lowercased().hasSuffix(".json") { fileName += ".json" }
      saveJson(jsonContent, fileName: fileName, result: result)

    case "shareFilesViaFileProvider":
      guard let args = call.arguments as? [String: Any] else {
        result(["success": false, "message": "Argumentos inválidos"])
        return
      }
      let filePaths = args["filePaths"] as? [String] ?? []
      let text = args["text"] as? String
      shareFiles(filePaths: filePaths, text: text, result: result)

    case "listSavedPlans":
      result(listSavedPlans())

    case "readSavedPlanFile":
      guard let args = call.arguments as? [String: Any],
            let fileName = args["fileName"] as? String else {
        result(["success": false, "message": "Nome vazio"])
        return
      }
      readSavedPlanFile(fileName: fileName, result: result)

    case "copyGalleryMediaToTemp":
      guard let args = call.arguments as? [String: Any] else {
        result([String: String]())
        return
      }
      let fileNames = args["fileNames"] as? [String] ?? []
      let destDir = args["destDir"] as? String ?? ""
      result(copyGalleryMediaToTemp(fileNames: fileNames, destDir: destDir))

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Paths

  private func monitoreDirectory() -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let dir = docs.appendingPathComponent("monitore", isDirectory: true)
    if !FileManager.default.fileExists(atPath: dir.path) {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    return dir
  }

  private func picturesDirectory() -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let dir = docs.appendingPathComponent("Pictures", isDirectory: true)
    if !FileManager.default.fileExists(atPath: dir.path) {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    return dir
  }

  // MARK: - Save image

  private func saveImageBytes(_ data: Data, fileName: String, result: @escaping FlutterResult) {
    // Always keep a copy in app Documents/Pictures for share fallback.
    let localFile = picturesDirectory().appendingPathComponent(fileName)
    do {
      try data.write(to: localFile)
    } catch {
      result(["success": false, "message": "Erro ao salvar localmente: \(error.localizedDescription)"])
      return
    }

    guard let image = UIImage(data: data) else {
      result(["success": true, "message": "Imagem salva localmente", "path": localFile.path])
      return
    }

    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        self.finishSaveImage(image: image, localFile: localFile, status: status, result: result)
      }
    } else {
      PHPhotoLibrary.requestAuthorization { status in
        self.finishSaveImage(image: image, localFile: localFile, status: status, result: result)
      }
    }
  }

  private func finishSaveImage(image: UIImage, localFile: URL, status: PHAuthorizationStatus, result: @escaping FlutterResult) {
    let authorized: Bool
    if #available(iOS 14, *) {
      authorized = status == .authorized || status == .limited
    } else {
      authorized = status == .authorized
    }
    guard authorized else {
      DispatchQueue.main.async {
        result(["success": true, "message": "Imagem salva localmente (sem permissão da galeria)", "path": localFile.path])
      }
      return
    }
    PHPhotoLibrary.shared().performChanges({
      PHAssetCreationRequest.creationRequestForAsset(from: image)
    }) { success, error in
      DispatchQueue.main.async {
        if success {
          result(["success": true, "message": "Imagem salva na galeria", "path": localFile.path])
        } else {
          result(["success": true, "message": "Imagem salva localmente: \(error?.localizedDescription ?? "")", "path": localFile.path])
        }
      }
    }
  }

  // MARK: - Save JSON

  private func saveJson(_ jsonContent: String, fileName: String, result: @escaping FlutterResult) {
    let fileURL = monitoreDirectory().appendingPathComponent(fileName)
    do {
      try jsonContent.write(to: fileURL, atomically: true, encoding: .utf8)
      result(["success": true, "path": "Documents/monitore/\(fileName)"])
    } catch {
      result(["success": false, "message": "Erro ao salvar JSON: \(error.localizedDescription)"])
    }
  }

  // MARK: - List / Read

  private func listSavedPlans() -> [[String: Any]] {
    let dir = monitoreDirectory()
    guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else {
      return []
    }
    return files
      .filter { $0.pathExtension.lowercased() == "json" }
      .compactMap { url -> [String: Any]? in
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let dateMs = Int((values?.contentModificationDate?.timeIntervalSince1970 ?? 0) * 1000)
        return [
          "fileName": url.lastPathComponent,
          "dateMs": dateMs,
          "size": values?.fileSize ?? 0,
        ]
      }
      .sorted { ($0["dateMs"] as? Int ?? 0) > ($1["dateMs"] as? Int ?? 0) }
  }

  private func readSavedPlanFile(fileName: String, result: @escaping FlutterResult) {
    guard !fileName.isEmpty else {
      result(["success": false, "message": "Nome vazio"])
      return
    }
    let fileURL = monitoreDirectory().appendingPathComponent(fileName)
    guard FileManager.default.fileExists(atPath: fileURL.path),
          let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
      result(["success": false, "message": "Arquivo não encontrado: \(fileName)"])
      return
    }
    result(["success": true, "content": content])
  }

  // MARK: - Copy media

  private func copyGalleryMediaToTemp(fileNames: [String], destDir: String) -> [String: String] {
    guard !fileNames.isEmpty, !destDir.isEmpty else { return [:] }
    let destURL = URL(fileURLWithPath: destDir, isDirectory: true)
    if !FileManager.default.fileExists(atPath: destURL.path) {
      try? FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)
    }
    var result = [String: String]()
    let pictures = picturesDirectory()
    for name in fileNames where !name.isEmpty {
      let src = pictures.appendingPathComponent(name)
      if FileManager.default.fileExists(atPath: src.path) {
        let dst = destURL.appendingPathComponent(name)
        do {
          if FileManager.default.fileExists(atPath: dst.path) {
            try FileManager.default.removeItem(at: dst)
          }
          try FileManager.default.copyItem(at: src, to: dst)
          result[name] = dst.path
        } catch {
          NSLog("copyGalleryMediaToTemp failed for \(name): \(error.localizedDescription)")
        }
      }
    }
    return result
  }

  // MARK: - Share

  private func shareFiles(filePaths: [String], text: String?, result: @escaping FlutterResult) {
    guard !filePaths.isEmpty else {
      result(["success": false, "message": "Nenhum arquivo para compartilhar"])
      return
    }
    DispatchQueue.main.async {
      if let alert = Self.topViewController() as? UIAlertController {
        alert.dismiss(animated: false) {
          Self.presentShareSheet(filePaths: filePaths, text: text, result: result)
        }
        return
      }
      if let presenter = Self.topViewController(),
         let alert = presenter.presentedViewController as? UIAlertController {
        alert.dismiss(animated: false) {
          Self.presentShareSheet(filePaths: filePaths, text: text, result: result)
        }
        return
      }
      Self.presentShareSheet(filePaths: filePaths, text: text, result: result)
    }
  }

  private static func presentShareSheet(filePaths: [String], text: String?, result: @escaping FlutterResult) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
      guard let presenter = topViewController() else {
        result(["success": false, "message": "Não foi possível abrir o compartilhamento"])
        return
      }
      var items: [Any] = []
      if let text, !text.isEmpty { items.append(text) }
      for path in filePaths where FileManager.default.fileExists(atPath: path) {
        items.append(URL(fileURLWithPath: path))
      }
      guard !items.isEmpty else {
        result(["success": false, "message": "Nenhum URI valido para compartilhar"])
        return
      }
      let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
      if let popover = activityVC.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
        popover.permittedArrowDirections = []
      }
      activityVC.completionWithItemsHandler = { _, _, _, _ in
        result(["success": true, "message": "Compartilhamento iniciado"])
      }
      presenter.present(activityVC, animated: true)
    }
  }

  private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
    let root: UIViewController? = {
      if let base { return base }
      let scene = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }
      return scene?.windows.first { $0.isKeyWindow }?.rootViewController
    }()
    if let nav = root as? UINavigationController { return topViewController(base: nav.visibleViewController) }
    if let tab = root as? UITabBarController { return topViewController(base: tab.selectedViewController) }
    if let presented = root?.presentedViewController { return topViewController(base: presented) }
    return root
  }
}
