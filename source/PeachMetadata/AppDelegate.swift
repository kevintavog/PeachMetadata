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

    private var hasInitialized = false


    override init()
    {
        super.init()

        #if DEBUG
            defaultDebugLevel = DDLogLevel.Verbose
        #else
            defaultDebugLevel = DDLogLevel.Info
        #endif
        Logger.configure()

        Preferences.setMissingDefaults()
        OpenMapLookupProvider.BaseLocationLookup = Preferences.baseLocationLookup
        Logger.info("Placename lookups via \(OpenMapLookupProvider.BaseLocationLookup), using level \(Preferences.placenameLevel) and filter \(Preferences.placenameFilter)")
    }

    func applicationDidFinishLaunching(aNotification: NSNotification)
    {
        hasInitialized = true
    }

    func application(sender: NSApplication, openFile filename: String) -> Bool
    {
        if !hasInitialized {
            Logger.warn("Opening folder before init? \(filename)")
            return true
        }

        peachWindowController.populateDirectoryView(filename)
        return true
    }
}
