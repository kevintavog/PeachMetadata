//
//  PeachMetadata
//

import AppKit
import Quartz
import WebKit

import RangicCore

class PeachWindowController : NSWindowController, NSTableViewDataSource, WebFrameLoadDelegate
{
    @IBOutlet weak var directoryView: NSOutlineView!
    @IBOutlet weak var imageBrowserView: IKImageBrowserView!
    @IBOutlet weak var fileTypeFilter: NSComboBox!
    @IBOutlet weak var thumbSizeSlider: NSSlider!
    @IBOutlet weak var mediaKeywordsTableView: NSTableView!
    @IBOutlet weak var allKeywordsTableView: NSTableView!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var mapView: WebView!


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
    }
}
