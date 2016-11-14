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
    @IBOutlet weak var peachWindowController: PeachWindowController!


    fileprivate var hasInitialized = false


    override init()
    {
        super.init()

        #if DEBUG
            defaultDebugLevel = DDLogLevel.verbose
        #else
            defaultDebugLevel = DDLogLevel.info
        #endif
        Logger.configure()

        Preferences.setMissingDefaults()
        OpenMapLookupProvider.BaseLocationLookup = Preferences.baseLocationLookup
        Logger.info("Placename lookups via \(OpenMapLookupProvider.BaseLocationLookup)")
        SupportedMediaTypes.includeRawImages = true
    }

    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        hasInitialized = true
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool
    {
        if !hasInitialized {
            Logger.warn("Opening folder before init? \(filename)")
            return true
        }

        peachWindowController.populateDirectoryView(filename)
        return true
    }
}
