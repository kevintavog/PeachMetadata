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
        newAttrs.setValue(NSColor.white, forKey: NSForegroundColorAttributeName)
        imageBrowserView.setValue(newAttrs, forKey: IKImageBrowserCellsTitleAttributesKey)

        thumbSizeSlider.floatValue = Preferences.thumbnailZoom
        imageBrowserView.setZoomValue(Preferences.thumbnailZoom)
        setFolderStatus()

        if Preferences.lastOpenedFolder.characters.count > 0 {
            populateDirectoryView(Preferences.lastOpenedFolder)
        }

        if Preferences.lastSelectedFolder.characters.count > 0 {
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
        if 1 != dialog.runModal() || dialog.urls.count < 1 {
            return
        }

        Preferences.lastImportedFolder = dialog.urls[0].path
        let importMediaController = ImportMediaWindowsController(windowNibName: "ImportMediaWindow")
        if importMediaController.setImportFolder(dialog.urls[0].path) {
            let result = NSApplication.shared().runModal(for: importMediaController.window!)
            if result == 1 {
                 populateDirectoryView(rootDirectory!.folder)
                Logger.error("Refresh folder list; select imported folder...")
            }
        }
    }

    func getLastImportFolder() -> String?
    {
        if Preferences.lastImportedFolder.characters.count > 0 {
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
        Logger.info("fixBadExif")
        PeachWindowController.showWarning("Not implemented")
    }
    
    @IBAction func viewFile(_ sender: AnyObject)
    {
        Logger.info("viewFile")
        let mediaItems = selectedMediaItems()
        if mediaItems.count != 1 {
            Logger.info("Only 1 file can be opened, there are \(mediaItems.count) selected")
            return
        }

        if NSWorkspace.shared().open(mediaItems.first!.url!) == false {
            PeachWindowController.showWarning("Failed opening file: '\(mediaItems.first!.url!.path)'")
        }
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
        let dateAdjustmentController = DateAdjustmentWindowController(windowNibName: "DateAdjustmentWindow")
        dateAdjustmentController.setDateValues(firstMediaData.fileTimestamp, metadataDate: firstMediaData.timestamp)
        let result = NSApplication.shared().runModal(for: dateAdjustmentController.window!)

        if result == 1 {
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
        alert.alertStyle = NSAlertStyle.warning
        alert.addButton(withTitle: "Close")
        alert.runModal()
    }

    static func askQuestion(_ message: String) -> Bool
    {
        Logger.warn(message)
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = NSAlertStyle.warning
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")
        return alert.runModal() == NSAlertFirstButtonReturn
    }
}
