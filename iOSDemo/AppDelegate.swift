import UIKit

@UIApplicationMain
class AppDelegate: UIResponder {
    var window: UIWindow?
}

extension AppDelegate: UIApplicationDelegate {

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)

        let controller = OptionsController(nibName: nil, bundle: nil)
        let navigationController = UINavigationController(rootViewController: controller)
        window?.rootViewController = navigationController

        window?.makeKeyAndVisible()

        return true
    }
}
