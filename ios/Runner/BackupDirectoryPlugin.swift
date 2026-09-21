import Flutter
import UIKit
import UniformTypeIdentifiers

/// Native iOS support for picking a directory and keeping access via a
/// security-scoped bookmark (required outside the app sandbox).
final class BackupDirectoryPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  private static let channelName = "vocabulary_trainer/backup_directory"

  private var pendingResult: FlutterResult?
  private var accessedURL: URL?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = BackupDirectoryPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickDirectory":
      pickDirectory(result: result)
    case "startAccess":
      guard
        let args = call.arguments as? [String: Any],
        let bookmark = args["bookmark"] as? String
      else {
        result(
          FlutterError(
            code: "bad_args",
            message: "bookmark is required",
            details: nil
          )
        )
        return
      }
      startAccess(bookmarkBase64: bookmark, result: result)
    case "stopAccess":
      stopAccess()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func pickDirectory(result: @escaping FlutterResult) {
    if pendingResult != nil {
      result(
        FlutterError(
          code: "busy",
          message: "A directory picker is already open.",
          details: nil
        )
      )
      return
    }

    guard let presenter = topViewController() else {
      result(
        FlutterError(
          code: "no_presenter",
          message: "Could not find a view controller to present the folder picker.",
          details: nil
        )
      )
      return
    }

    pendingResult = result

    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(
        forOpeningContentTypes: [UTType.folder],
        asCopy: false
      )
    } else {
      picker = UIDocumentPickerViewController(
        documentTypes: ["public.folder"],
        in: .open
      )
    }

    picker.delegate = self
    picker.allowsMultipleSelection = false
    picker.modalPresentationStyle = .formSheet
    presenter.present(picker, animated: true)
  }

  private func startAccess(bookmarkBase64: String, result: @escaping FlutterResult) {
    stopAccess()

    guard let data = Data(base64Encoded: bookmarkBase64) else {
      result(
        FlutterError(
          code: "bad_bookmark",
          message: "The stored bookmark could not be decoded.",
          details: nil
        )
      )
      return
    }

    do {
      var isStale = false
      let url = try URL(
        resolvingBookmarkData: data,
        options: [],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )

      guard url.startAccessingSecurityScopedResource() else {
        result(
          FlutterError(
            code: "access_denied",
            message: "Could not start access to the selected folder.",
            details: nil
          )
        )
        return
      }

      accessedURL = url
      result([
        "path": url.path,
        "isStale": isStale,
      ])
    } catch {
      result(
        FlutterError(
          code: "resolve_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func stopAccess() {
    if let accessedURL {
      accessedURL.stopAccessingSecurityScopedResource()
      self.accessedURL = nil
    }
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let result = pendingResult else { return }
    pendingResult = nil

    guard let url = urls.first else {
      result(nil)
      return
    }

    let accessStarted = url.startAccessingSecurityScopedResource()
    defer {
      if accessStarted {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      // iOS uses a standard bookmark for document-picker security-scoped URLs.
      let bookmarkData = try url.bookmarkData(
        options: [],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )

      result([
        "path": url.path,
        "bookmark": bookmarkData.base64EncodedString(),
      ])
    } catch {
      result(
        FlutterError(
          code: "bookmark_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingResult?(nil)
    pendingResult = nil
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap {
      $0 as? UIWindowScene
    }
    for scene in scenes {
      for window in scene.windows where window.isKeyWindow {
        return topMost(from: window.rootViewController)
      }
    }
    return topMost(
      from: scenes.first?.windows.first?.rootViewController
    )
  }

  private func topMost(from controller: UIViewController?) -> UIViewController? {
    if let navigation = controller as? UINavigationController {
      return topMost(from: navigation.visibleViewController)
    }
    if let tab = controller as? UITabBarController {
      return topMost(from: tab.selectedViewController)
    }
    if let presented = controller?.presentedViewController {
      return topMost(from: presented)
    }
    return controller
  }
}
