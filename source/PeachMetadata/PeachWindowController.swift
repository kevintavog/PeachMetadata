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


    override func awakeFromNib()
    {
        imageBrowserView.setValue(NSColor.darkGrayColor(), forKey: IKImageBrowserBackgroundColorKey)
        let newAttrs = imageBrowserView.valueForKey(IKImageBrowserCellsTitleAttributesKey)?.mutableCopy()
        newAttrs?.setValue(NSColor.whiteColor(), forKey: NSForegroundColorAttributeName)
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
        allKeywordsTableView.setDelegate(allKeywordsController)
        allKeywordsTableView.setDataSource(allKeywordsController)

        mediaKeywordsController = MediaKeywordsTableController(tableView: mediaKeywordsTableView)
        mediaKeywordsTableView.setDelegate(mediaKeywordsController)
        mediaKeywordsTableView.setDataSource(mediaKeywordsController)

        mapView.mainFrame.loadRequest(NSURLRequest(URL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("map", ofType: "html")!)))
        mapView.frameLoadDelegate = self
        mapView.enableDragAndDrop(updateLocations)
    }

    @IBAction func importMedia(sender: AnyObject)
    {
        let dialog = NSOpenPanel()

        dialog.canChooseFiles = false
        dialog.canChooseDirectories = true
        if let path = getLastImportFolder() {
            dialog.directoryURL = NSURL(fileURLWithPath: path, isDirectory: true)
        }
        if 1 != dialog.runModal() || dialog.URLs.count < 1 {
            return
        }

        Preferences.lastImportedFolder = dialog.URLs[0].path!
        let importMediaController = ImportMediaWindowsController(windowNibName: "ImportMediaWindow")
        if importMediaController.setImportFolder(dialog.URLs[0].path!) {
            let result = NSApplication.sharedApplication().runModalForWindow(importMediaController.window!)
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
            if NSFileManager.defaultManager().fileExistsAtPath(Preferences.lastImportedFolder, isDirectory:&isFolder) && isFolder {
                return Preferences.lastImportedFolder
            }

            let parentPath = NSString(string: Preferences.lastImportedFolder).stringByDeletingLastPathComponent
            if NSFileManager.defaultManager().fileExistsAtPath(parentPath, isDirectory:&isFolder) && isFolder {
                return parentPath
            }
        }
        return nil
    }

    @IBAction func clearLocations(sender: AnyObject)
    {
        let mediaItems = selectedMediaItems()
        if mediaItems.count < 1 {
            return
        }

        clearLocations(mediaItems)
    }

    @IBAction func fixBadExif(sender: AnyObject)
    {
        Logger.info("fixBadExif")
        PeachWindowController.showWarning("Not implemented")
    }
    
    @IBAction func viewFile(sender: AnyObject)
    {
        Logger.info("viewFile")
        let mediaItems = selectedMediaItems()
        if mediaItems.count != 1 {
            Logger.info("Only 1 file can be opened, there are \(mediaItems.count) selected")
            return
        }

        if NSWorkspace.sharedWorkspace().openURL(mediaItems.first!.url!) == false {
            PeachWindowController.showWarning("Failed opening file: '\(mediaItems.first!.url!.path)'")
        }
    }

    @IBAction func showDetails(sender: AnyObject)
    {
        Logger.info("showDetails")
        fileInformationController.toggleVisibility()
    }
    
    @IBAction func setAllMetadataDates(sender: AnyObject)
    {
        Logger.info("setAllMetadataDates")
        let mediaItems = selectedMediaItems()
        if mediaItems.count < 1 {
            return
        }


        var filePaths = [String]()
        for mediaData in mediaItems {
            filePaths.append(mediaData.url!.path!)
        }

        let (_, videoPathList) = separateVideoList(filePaths)
        if videoPathList.count < 1 {
            return
        }

        let firstMediaData = mediaItems.first!
        let dateAdjustmentController = DateAdjustmentWindowController(windowNibName: "DateAdjustmentWindow")
        dateAdjustmentController.setDateValues(firstMediaData.fileTimestamp, metadataDate: firstMediaData.timestamp)
        let result = NSApplication.sharedApplication().runModalForWindow(dateAdjustmentController.window!)

        if result == 1 {
            Async.background {
                do {
                    if let newDate = dateAdjustmentController.newDate() {
                        try ExifToolRunner.setMetadataDates(videoPathList, newDate: newDate)

                        for file in filePaths {
                            if let mediaData = self.mediaProvider.itemFromFilePath(file) {
                                mediaData.timestamp = newDate
                                mediaData.fileTimestamp = newDate
                            }
                        }

                        self.mediaProvider.setFileDatesToExifDates(mediaItems)
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

    @IBAction func toggleLocationIssues(sender: AnyObject)
    {
        Logger.info("toggleLocationIssues")
        filterItems()
    }

    @IBAction func toggleDateIssues(sender: AnyObject)
    {
        Logger.info("toggleDateIssues")
        filterItems()
    }

    @IBAction func toggleKeywordIssues(sender: AnyObject)
    {
        Logger.info("toggleKeywordIssues")
        filterItems()
    }

    @IBAction func allKeywordClick(sender: AnyObject)
    {
        allKeywordsController.keywordToggled()
        allKeywordsController.updateTable()
        mediaKeywordsController.updateTable()
    }

    @IBAction func mediaItemKeywordClick(sender: AnyObject)
    {
        mediaKeywordsController.keywordToggled()
        mediaKeywordsController.updateTable()
        allKeywordsController.updateTable()
    }

    static func showWarning(message: String)
    {
        Logger.error(message)
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = NSAlertStyle.WarningAlertStyle
        alert.addButtonWithTitle("Close")
        alert.runModal()
    }

    static func askQuestion(message: String) -> Bool
    {
        Logger.warn(message)
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = NSAlertStyle.WarningAlertStyle
        alert.addButtonWithTitle("Yes")
        alert.addButtonWithTitle("No")
        return alert.runModal() == NSAlertFirstButtonReturn
    }
}
