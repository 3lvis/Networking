#if os(iOS)
    import UIKit
#endif

public class NetworkActivityIndicator: NSObject {

    /**
     The shared instance.
     */
    public static let sharedIndicator = NetworkActivityIndicator()

    /**
     The number of activities in progress.
     */
    internal var activitiesCount = 0

    /**
     A Boolean value that turns an indicator of network activity on or off.

     Specify true if the app should show network activity and false if it should not. The default value is false. A spinning indicator in the status bar shows network activity. Multiple calls to visible cause an internal counter to take care of persisting the number of times this method has being called.
     */
    public var visible: Bool = false {
        didSet {
            if visible {
                self.activitiesCount += 1
            } else {
                self.activitiesCount -= 1
            }

            if self.activitiesCount < 0 {
                self.activitiesCount = 0
            }

            #if os(iOS)
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = (self.activitiesCount > 0)
                })
            #endif
        }
    }
}
