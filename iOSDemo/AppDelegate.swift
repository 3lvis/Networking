import UIKit

@UIApplicationMain
class AppDelegate: UIResponder {
    var window: UIWindow?
}

extension AppDelegate: UIApplicationDelegate {

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        self.window = UIWindow(frame: UIScreen.main.bounds)

        let controller = OptionsController(nibName: nil, bundle: nil)
        let navigationController = UINavigationController(rootViewController: controller)
        self.window?.rootViewController = navigationController

        self.window?.makeKeyAndVisible()

        return true
    }
}
