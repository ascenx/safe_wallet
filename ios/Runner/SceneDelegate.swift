import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let url = connectionOptions.urlContexts.first?.url,
      let appDelegate = UIApplication.shared.delegate as? AppDelegate
    {
      _ = appDelegate.handleWalletConnectUrl(url)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url,
      let appDelegate = UIApplication.shared.delegate as? AppDelegate,
      appDelegate.handleWalletConnectUrl(url)
    {
      return
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
