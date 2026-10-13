import Flutter
import UIKit
import WebKit
import webview_flutter_wkwebview

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var webViewChannel: FlutterMethodChannel?
  private var cryptoChannel: FlutterMethodChannel?
  private var appInfoChannel: FlutterMethodChannel?
  private var walletConnectLinkChannel: FlutterMethodChannel?
  private var securityChannel: FlutterMethodChannel?
  private var sensitiveClipboardChannel: FlutterMethodChannel?
  private var pendingWalletConnectLink: String?
  private var sensitiveScreenProtectionEnabled = false
  private var captureShieldView: UIVisualEffectView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL {
      pendingWalletConnectLink = walletConnectUri(url)
    }
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureStateChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    installWebViewChannel(engineBridge)
    installCryptoChannel(engineBridge)
    installAppInfoChannel(engineBridge)
    installWalletConnectLinkChannel(engineBridge)
    installSecurityChannel(engineBridge)
    installSensitiveClipboardChannel(engineBridge)
  }

  private func installSensitiveClipboardChannel(
    _ engineBridge: FlutterImplicitEngineBridge
  ) {
    sensitiveClipboardChannel = FlutterMethodChannel(
      name: "safe_wallet/sensitive_clipboard",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    sensitiveClipboardChannel?.setMethodCallHandler { call, result in
      guard let args = call.arguments as? [String: Any],
        let text = args["text"] as? String
      else {
        result(FlutterError(
          code: "invalid_arguments",
          message: "Missing clipboard text.",
          details: nil
        ))
        return
      }
      switch call.method {
      case "copySensitiveText":
        let seconds = (args["expiresAfterSeconds"] as? NSNumber)?.doubleValue ?? 30
        UIPasteboard.general.setItems(
          [["public.utf8-plain-text": text]],
          options: [
            UIPasteboard.OptionsKey.localOnly: true,
            UIPasteboard.OptionsKey.expirationDate: Date(
              timeIntervalSinceNow: max(1, seconds)
            ),
          ]
        )
        result(nil)
      case "clearSensitiveClipboardIfMatches":
        if UIPasteboard.general.string == text {
          UIPasteboard.general.items = []
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func installSecurityChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    securityChannel = FlutterMethodChannel(
      name: "safe_wallet/security",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    securityChannel?.setMethodCallHandler { call, result in
      switch call.method {
      case "setSensitiveScreenProtection":
        let args = call.arguments as? [String: Any]
        self.sensitiveScreenProtectionEnabled = args?["enabled"] as? Bool ?? false
        self.updateCaptureShield()
        result(nil)
      case "excludeWalletStorageFromBackup":
        self.excludeWalletStorageFromBackup(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @objc private func screenCaptureStateChanged() {
    updateCaptureShield()
  }

  private func updateCaptureShield() {
    let shouldShield = sensitiveScreenProtectionEnabled && UIScreen.main.isCaptured
    if !shouldShield {
      captureShieldView?.removeFromSuperview()
      captureShieldView = nil
      return
    }
    guard captureShieldView == nil, let window = activeWindow() else {
      return
    }
    let shield = UIVisualEffectView(
      effect: UIBlurEffect(style: .systemChromeMaterialDark)
    )
    shield.translatesAutoresizingMaskIntoConstraints = false
    shield.isUserInteractionEnabled = true
    window.addSubview(shield)
    NSLayoutConstraint.activate([
      shield.leadingAnchor.constraint(equalTo: window.leadingAnchor),
      shield.trailingAnchor.constraint(equalTo: window.trailingAnchor),
      shield.topAnchor.constraint(equalTo: window.topAnchor),
      shield.bottomAnchor.constraint(equalTo: window.bottomAnchor),
    ])
    captureShieldView = shield
  }

  private func activeWindow() -> UIWindow? {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
  }

  private func excludeWalletStorageFromBackup(result: FlutterResult) {
    guard var storageUrl = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).first else {
      result(FlutterError(
        code: "storage_path_unavailable",
        message: "Unable to locate wallet storage.",
        details: nil
      ))
      return
    }
    storageUrl.appendPathComponent("safe_wallet", isDirectory: true)
    do {
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try storageUrl.setResourceValues(values)
      result(nil)
    } catch {
      result(FlutterError(
        code: "backup_exclusion_failed",
        message: "Unable to exclude wallet storage from backup.",
        details: nil
      ))
    }
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if handleWalletConnectUrl(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func handleWalletConnectUrl(_ url: URL) -> Bool {
    guard let value = walletConnectUri(url) else {
      return false
    }
    pendingWalletConnectLink = value
    walletConnectLinkChannel?.invokeMethod("onLink", arguments: value)
    return true
  }

  private func installWalletConnectLinkChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    walletConnectLinkChannel = FlutterMethodChannel(
      name: "safe_wallet/wallet_connect_link",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    walletConnectLinkChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "getInitialLink" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.pendingWalletConnectLink)
    }
  }

  private func walletConnectUri(_ url: URL) -> String? {
    if url.scheme?.lowercased() == "wc" {
      return url.absoluteString
    }
    guard url.scheme?.lowercased() == "safewallet",
      url.host?.lowercased() == "walletconnect",
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let value = components.queryItems?.first(where: { $0.name == "uri" })?.value,
      value.hasPrefix("wc:")
    else {
      return nil
    }
    return value
  }

  private func installAppInfoChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    appInfoChannel = FlutterMethodChannel(
      name: "safe_wallet/app_info",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    appInfoChannel?.setMethodCallHandler { call, result in
      guard call.method == "getAppVersion" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let info = Bundle.main.infoDictionary
      result([
        "version": info?["CFBundleShortVersionString"] as? String ?? "1.0.1",
        "buildNumber": info?["CFBundleVersion"] as? String ?? "5",
      ])
    }
  }

  private func installCryptoChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    cryptoChannel = FlutterMethodChannel(
      name: "safe_wallet/crypto",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    cryptoChannel?.setMethodCallHandler { call, result in
      switch call.method {
      case "derivePbkdf2HmacSha256":
        self.derivePbkdf2HmacSha256(call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func derivePbkdf2HmacSha256(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
      let password = args["password"] as? String,
      let saltData = args["salt"] as? FlutterStandardTypedData,
      let iterationsValue = int64Value(args["iterations"]),
      iterationsValue > 0,
      iterationsValue <= Int64(UInt32.max),
      let bitsValue = int64Value(args["bits"]),
      bitsValue >= 64,
      bitsValue % 8 == 0,
      bitsValue / 8 <= Int64(Int.max)
    else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "Invalid PBKDF2 parameters.",
        details: nil
      ))
      return
    }

    let passwordData = Data(password.utf8)
    let salt = saltData.data
    let iterations = UInt32(iterationsValue)
    let outputLength = Int(bitsValue / 8)

    DispatchQueue.global(qos: .userInitiated).async {
      var output = [UInt8](repeating: 0, count: outputLength)
      let status = passwordData.withUnsafeBytes { passwordBytes in
        salt.withUnsafeBytes { saltBytes in
          output.withUnsafeMutableBytes { outputBytes in
            CCKeyDerivationPBKDF(
              CCPBKDFAlgorithm(kCCPBKDF2),
              passwordBytes.bindMemory(to: Int8.self).baseAddress,
              passwordData.count,
              saltBytes.bindMemory(to: UInt8.self).baseAddress,
              salt.count,
              CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
              iterations,
              outputBytes.bindMemory(to: UInt8.self).baseAddress,
              outputLength
            )
          }
        }
      }

      DispatchQueue.main.async {
        if status == kCCSuccess {
          result(FlutterStandardTypedData(bytes: Data(output)))
        } else {
          result(FlutterError(
            code: "kdf_failed",
            message: "Unable to derive the wallet key.",
            details: nil
          ))
        }
      }
    }
  }

  private func installWebViewChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    webViewChannel = FlutterMethodChannel(
      name: "safe_wallet/webview",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    webViewChannel?.setMethodCallHandler { call, result in
      switch call.method {
      case "addDocumentStartScript":
        self.addDocumentStartScript(call, engineBridge: engineBridge, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func addDocumentStartScript(
    _ call: FlutterMethodCall,
    engineBridge: FlutterImplicitEngineBridge,
    result: FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
      let source = args["source"] as? String,
      let webViewIdentifier = int64Value(args["webViewIdentifier"])
    else {
      print("[SafeWalletDapp] addDocumentStartScript invalid_arguments")
      result(FlutterError(
        code: "invalid_arguments",
        message: "Missing webViewIdentifier or source.",
        details: nil
      ))
      return
    }

    print(
      "[SafeWalletDapp] addDocumentStartScript request " +
        "webViewIdentifier=\(webViewIdentifier) sourceLength=\(source.count)"
    )

    guard let webView = FWFWebViewFlutterWKWebViewExternalAPI.webView(
      forIdentifier: webViewIdentifier,
      withPluginRegistry: engineBridge.pluginRegistry
    ) else {
      print(
        "[SafeWalletDapp] addDocumentStartScript webview_not_found " +
          "webViewIdentifier=\(webViewIdentifier)"
      )
      result(FlutterError(
        code: "webview_not_found",
        message: "Unable to find WKWebView for identifier \(webViewIdentifier).",
        details: nil
      ))
      return
    }

    let script = WKUserScript(
      source: source,
      injectionTime: .atDocumentStart,
      forMainFrameOnly: true
    )
    webView.configuration.userContentController.addUserScript(script)
    print(
      "[SafeWalletDapp] addDocumentStartScript success " +
        "webViewIdentifier=\(webViewIdentifier)"
    )
    result(nil)
  }

  private func int64Value(_ value: Any?) -> Int64? {
    switch value {
    case let value as Int64:
      return value
    case let value as Int:
      return Int64(value)
    case let value as Int32:
      return Int64(value)
    case let value as NSNumber:
      return value.int64Value
    default:
      return nil
    }
  }
}
