//
//  PeachMetadata
//

import AppKit
import Quartz
import WebKit

import Async
import RangicCore

class PeachWindowController : NSWindowController, NSTableViewDataSource, WebFrameLoadDelegate, WebUIDelegate
{
    @IBOutlet weak var directoryView: NSOutlineView!
    @IBOutlet weak var imageBrowserView: IKImageBrowserView!
    @IBOutlet weak var fileTypeFilter: NSComboBox!
    @IBOutlet weak var thumbSizeSlider: NSSlider!
    @IBOutlet weak var mediaKeywordsTableView: NSTableView!
    @IBOutlet weak var allKeywordsTableView: NSTableView!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var mapView: MapWebView!
    @IBOutlet weak var fileInformationController: FileInformationController!
    @IBOutlet weak var statusFileLabel: NSTextField!
    @IBOutlet weak var statusLocationLabel: NSButton!
    @IBOutlet weak var statusDateLabel: NSButton!
    @IBOutlet weak var statusKeywordLabel: NSButton!


    // So menu check marks can be toggled
    @IBOutlet weak var menuFollowSelectionOnMap: NSMenuItem!
    @IBOutlet weak var menuSatelliteMap: NSMenuItem!
    @IBOutlet weak var menuDarkMap: NSMenuItem!
    @IBOutlet weak var menuNormalMap: NSMenuItem!
    @IBOutlet weak var menuOpenStreetMap: NSMenuItem!
    @IBOutlet weak var menuShowImagesOnMap: NSMenuItem!


    var mediaProvider = MediaProvider()
    var thumbnailItems = [ThumbnailViewItem]()
    var filteredThumbnailItems = [ThumbnailViewItem]()
    var rootDirectory: DirectoryTree?
    var allKeywordsController: AllKeywordsTableViewController!
    var mediaKeywordsController: MediaKeywordsTableController!
    var selectedKeywords = FilesAndKeywords()
    var followSelectionOnMap = true

    override func awakeFromNib()
    {
        imageBrowserView.setValue(NSColor.darkGray, forKey: IKImageBrowserBackgroundColorKey)
        let newAttrs = NSMutableDictionary(dictionary: imageBrowserView.value(forKey: IKImageBrowserCellsTitleAttributesKey) as! [String:Any])
        newAttrs.setValue(NSColor.white, forKey: NSAttributedStringKey.foregroundColor.rawValue)
        imageBrowserView.setValue(newAttrs, forKey: IKImageBrowserCellsTitleAttributesKey)

        thumbSizeSlider.floatValue = Preferences.thumbnailZoom
        imageBrowserView.setZoomValue(Preferences.thumbnailZoom)
        setFolderStatus()

        if Preferences.lastOpenedFolder.count > 0 {
            populateDirectoryView(Preferences.lastOpenedFolder)
        }

        if Preferences.lastSelectedFolder.count > 0 {
            selectDirectoryViewRow(Preferences.lastSelectedFolder)
        }

        allKeywordsController = AllKeywordsTableViewController(tableView: allKeywordsTableView)
        allKeywordsTableView.delegate = allKeywordsController
        allKeywordsTableView.dataSource = allKeywordsController

        mediaKeywordsController = MediaKeywordsTableController(tableView: mediaKeywordsTableView)
        mediaKeywordsTableView.delegate = mediaKeywordsController
        mediaKeywordsTableView.dataSource = mediaKeywordsController

        mapView.mainFrame.load(URLRequest(url: URL(fileURLWithPath: Bundle.main.path(forResource: "map", ofType: "html")!)))
        mapView.frameLoadDelegate = self
        mapView.enableDragAndDrop(updateLocations)

        menuNormalMap?.state = .on
        menuFollowSelectionOnMap?.state = followSelectionOnMap ? .on : .off

        Notifications.addObserver(self, selector: #selector(PeachWindowController.mapViewMediaSelected(_:)), name: Notifications.Selection.MediaData, object: nil)
    }

    @IBAction func importMedia(_ sender: AnyObject)
    {
        let dialog = NSOpenPanel()

        dialog.canChooseFiles = false
        dialog.canChooseDirectories = true
        if let path = getLastImportFolder() {
            dialog.directoryURL = URL(fileURLWithPath: path, isDirectory: true)
        }
        if 1 != dialog.runModal().rawValue || dialog.urls.count < 1 {
            return
        }

        Preferences.lastImportedFolder = dialog.urls[0].path
        let importMediaController = ImportMediaWindowsController(windowNibName: NSNib.Name(rawValue: "ImportMediaWindow"))
        if importMediaController.setImportFolder(dialog.urls[0].path) {
            let result = NSApplication.shared.runModal(for: importMediaController.window!)
            if result.rawValue == 1 {
                 populateDirectoryView(rootDirectory!.folder)
                Logger.error("Refresh folder list; select imported folder...")
            }
        }
    }

    func getLastImportFolder() -> String?
    {
        if Preferences.lastImportedFolder.count > 0 {
            var isFolder: ObjCBool = false
            if FileManager.default.fileExists(atPath: Preferences.lastImportedFolder, isDirectory:&isFolder) && isFolder.boolValue {
                return Preferences.lastImportedFolder
            }

            let parentPath = NSString(string: Preferences.lastImportedFolder).deletingLastPathComponent
            if FileManager.default.fileExists(atPath: parentPath, isDirectory:&isFolder) && isFolder.boolValue {
                return parentPath
            }
        }
        return nil
    }

    @IBAction func clearLocations(_ sender: AnyObject)
    {
        let mediaItems = selectedMediaItems()
        if mediaItems.count < 1 {
            return
        }

        clearLocations(mediaItems)
    }

    @IBAction func fixBadExif(_ sender: AnyObject)
    {
        let mediaItems = selectedMediaItems()
        if mediaItems.count < 1 {
            return
        }

        fixBadExif(mediaItems)
    }
    
    @IBAction func viewFile(_ sender: AnyObject)
    {
        Logger.info("viewFile")
        let mediaItems = selectedMediaItems()
        if mediaItems.count != 1 {
            Logger.info("Only 1 file can be opened, there are \(mediaItems.count) selected")
            return
        }

        if NSWorkspace.shared.open(mediaItems.first!.url!) == false {
            PeachWindowController.showWarning("Failed opening file: '\(mediaItems.first!.url!.path)'")
        }
    }

    @IBAction func copyLatLon(_ sender: Any) {
        visitFirstSelectedItem( { (item: MediaData) -> () in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("\(item.location.latitude),\(item.location.longitude)", forType: NSPasteboard.PasteboardType.string)
        })
    }

    @IBAction func pasteLatLon(_ sender: Any) {
        // Ensure lat,lon on clipboard
        var clipboardText: String? = nil
        for item in NSPasteboard.general.pasteboardItems! {
            if let str = item.string(forType: NSPasteboard.PasteboardType(rawValue: "public.utf8-plain-text")) {
                clipboardText = str
                break
            }
        }

        if clipboardText == nil {
            PeachWindowController.showWarning("Can't find any text on the clipboard")
            return
        }

        // Expect two doubles, separated by a comma
        let locationTokens = clipboardText!.split(separator: ",")
        if locationTokens.count != 2 {
            PeachWindowController.showWarning("Can't find '<lat>,<lon>' in\n '\(clipboardText!)'\nPerhaps the comma is missing.")
            return
        }

        guard let lat = Double(locationTokens[0].trimmingCharacters(in: .whitespaces)), let lon = Double(locationTokens[1].trimmingCharacters(in: .whitespaces)) else {
            PeachWindowController.showWarning("Can't parse out '<lat>,<lon>' from\n '\(clipboardText!)'")
            return
        }


        // visit all selected items, apply lat/lon - but don't overwrite
        let mediaItems = selectedMediaItems()
        if mediaItems.count < 1 {
            PeachWindowController.showWarning("No items selected, nothing to paste the location to")
            return
        }

        var filePaths = [String]()
        for item in mediaItems {
            filePaths.append(item.url!.path)
        }
        updateLocations(Location(latitude: lat, longitude: lon), filePaths: filePaths)
    }

    @IBAction func showInAppleMaps(_ sender: Any) {
        launchLocationUrl( { (item: MediaData) -> (String) in
            return "http://maps.apple.com/?ll=\(item.location.latitude),\(item.location.longitude)"
        })
    }
    
    @IBAction func showInGoogleMaps(_ sender: Any) {
        launchLocationUrl( { (item: MediaData) -> (String) in
            return "http://maps.google.com/maps?q=\(item.location.latitude),\(item.location.longitude)"
        })
    }

    @IBAction func showInOpenStreetMap(_ sender: Any) {
        launchLocationUrl( { (item: MediaData) -> (String) in
            return "http://www.openstreetmap.org/?&mlat=\(item.location.latitude)&mlon=\(item.location.longitude)#map=18/\(item.location.latitude)/\(item.location.longitude)"
        })
    }

    @IBAction func showInStreetView(_ sender: Any) {
        launchLocationUrl( { (item: MediaData) -> (String) in
            return "http://maps.google.com/maps?q=&layer=c&cbll=\(item.location.latitude),\(item.location.longitude)&cbp=11,0,0,0,0"
        })
    }

    func visitFirstSelectedItem(_ visit: @escaping ( _ mediaItem: MediaData ) -> ()) {
        let mediaItems = selectedMediaItems()
        if mediaItems.count != 1 {
            Logger.info("Only 1 file can be opened, there are \(mediaItems.count) selected")
            return
        }

        if mediaItems.first?.location != nil {
            visit(mediaItems.first!)
        } else {
            PeachWindowController.showWarning("This item has no location info:\n \(mediaItems.first!.url!.path)")
        }
    }

    func launchLocationUrl(_ getUrl: @escaping ( _ mediaItem: MediaData ) -> (String)) {
        visitFirstSelectedItem( { (item: MediaData) -> () in
            let url = getUrl(item)
            Logger.info("Launching \(url)")
            NSWorkspace.shared.open(URL(string: url)!)
        })
    }
    
    @IBAction func showDetails(_ sender: AnyObject)
    {
        Logger.info("showDetails")
        fileInformationController.toggleVisibility()
    }
    
    @IBAction func setAllMetadataDates(_ sender: AnyObject)
    {
        Logger.info("setAllMetadataDates")
        let mediaItems = selectedMediaItems()
        if mediaItems.count < 1 {
            return
        }


        var filePaths = [String]()
        for mediaData in mediaItems {
            filePaths.append(mediaData.url!.path)
        }

        let (imagePathList, videoPathList) = separateVideoList(filePaths)
        if imagePathList.count < 1 && videoPathList.count < 1 {
            return
        }

        let firstMediaData = mediaItems.first!
        let dateAdjustmentController = DateAdjustmentWindowController(windowNibName: NSNib.Name(rawValue: "DateAdjustmentWindow"))
        dateAdjustmentController.setDateValues(firstMediaData.fileTimestamp, metadataDate: firstMediaData.timestamp)
        let result = NSApplication.shared.runModal(for: dateAdjustmentController.window!)

        if result.rawValue == 1 {
            Async.background {
                do {
                    if let newDate = dateAdjustmentController.newDate() {
                        try ExifToolRunner.setMetadataDates(imagePathList, videoFilePaths: videoPathList, newDate: newDate as NSDate)

                        for file in filePaths {
                            if let mediaData = self.mediaProvider.itemFromFilePath(file) {
                                mediaData.timestamp = newDate
                                mediaData.fileTimestamp = newDate
                            }
                        }

                        let _ = self.mediaProvider.setFileDatesToExifDates(mediaItems)
                        Async.main {
                            self.imageBrowserView.reloadData()
                        }
                    }
                } catch let error {
                    Logger.error("Setting metadata dates failed: \(error)")

                    Async.main {
                        self.setStatus("Setting metadata dates failed: \(error)")
                        PeachWindowController.showWarning("Setting metadata dates failed: \(error)")
                    }
                }
            }
        }

    }

    @IBAction func toggleLocationIssues(_ sender: AnyObject)
    {
        Logger.info("toggleLocationIssues")
        filterItems()
    }

    @IBAction func toggleDateIssues(_ sender: AnyObject)
    {
        Logger.info("toggleDateIssues")
        filterItems()
    }

    @IBAction func toggleKeywordIssues(_ sender: AnyObject)
    {
        Logger.info("toggleKeywordIssues")
        filterItems()
    }

    @IBAction func allKeywordClick(_ sender: AnyObject)
    {
        let button = sender as! NSButton
        allKeywordsController.keywordToggled(index: button.tag)
        allKeywordsController.updateTable()
        mediaKeywordsController.updateTable()
    }

    @IBAction func mediaItemKeywordClick(_ sender: AnyObject)
    {
        let button = sender as! NSButton
        mediaKeywordsController.keywordToggled(index: button.tag)
        mediaKeywordsController.updateTable()
        allKeywordsController.updateTable()
    }

    static func showWarning(_ message: String)
    {
        Logger.error(message)
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = NSAlert.Style.warning
        alert.addButton(withTitle: "Close")
        alert.runModal()
    }

    static func askQuestion(_ message: String) -> Bool
    {
        Logger.warn(message)
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = NSAlert.Style.warning
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")
        return alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn
    }
}
