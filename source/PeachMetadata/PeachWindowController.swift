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
    @IBOutlet weak var statusFileLabel: NSButton!
    @IBOutlet weak var statusLocationLabel: NSButton!
    @IBOutlet weak var statusDateLabel: NSButton!
    @IBOutlet weak var statusKeywordLabel: NSButton!

    
    var mediaProvider = MediaProvider()
    var thumbnailItems = [ThumbnailViewItem]()
    var rootDirectory: DirectoryTree?
    var allKeywordsController = AllKeywordsTableViewController()
    var mediaKeywordsController: MediaKeywordsTableController!


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


        allKeywordsTableView.setDelegate(allKeywordsController)
        allKeywordsTableView.setDataSource(allKeywordsController)

        mediaKeywordsController = MediaKeywordsTableController(tableView: mediaKeywordsTableView)
        mediaKeywordsTableView.setDelegate(mediaKeywordsController)
        mediaKeywordsTableView.setDataSource(mediaKeywordsController)

        mapView.mainFrame.loadRequest(NSURLRequest(URL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("map", ofType: "html")!)))
        mapView.frameLoadDelegate = self
        mapView.enableDragAndDrop(updateLocations)

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
    }
    
    @IBAction func viewFile(sender: AnyObject)
    {
        Logger.info("viewFile")
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
                    }
                }
            }
        }

    }

    @IBAction func validateFiles(sender: AnyObject)
    {
        Logger.info("validateFiles")
        var mediaItems = selectedMediaItems()
        if mediaItems.count < 1 {
            mediaItems = mediaProvider.mediaFiles
        }

        for media in mediaItems {
            Logger.info("Check \(media.name)")
            if !media.doesExist() {
                Logger.info("  file missing")
                continue
            }

            if let loc = media.location {
                if SensitiveLocations.sharedInstance.isSensitive(loc) {
                    Logger.info("  Is in a sensitive location")
                }
            }
            else {
                Logger.info("  No location")
            }


            if media.keywords == nil {
                Logger.info("  No keywords")
            }

            if !media.doFileAndExifTimestampsMatch() {
                Logger.info("  Mismatched dates")
            }
        }
    }
}
