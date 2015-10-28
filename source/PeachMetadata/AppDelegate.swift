//
//  PeachMetadata
//

import Cocoa
import RangicCore
import CocoaLumberjackSwift

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate
{
    @IBOutlet weak var window: NSWindow!

    func applicationDidFinishLaunching(aNotification: NSNotification)
    {
        #if DEBUG
            defaultDebugLevel = DDLogLevel.Verbose
            #else
            defaultDebugLevel = DDLogLevel.Info
        #endif
        Logger.configure()
    }
}
