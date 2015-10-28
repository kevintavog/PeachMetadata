//
//  PeachMetadata
//

import AppKit
import Quartz
import RangicCore

class PeachWindowController : NSWindowController
{
    @IBOutlet weak var directoryView: NSOutlineView!
    @IBOutlet weak var imageBrowserView: IKImageBrowserView!
    @IBOutlet weak var fileTypeFilter: NSComboBox!
    @IBOutlet weak var thumbSizeSlider: NSSlider!


    var mediaProvider = MediaProvider()
    var thumbnailItems = [ThumbnailViewItem]()
    var rootDirectory: DirectoryTree?


    override func awakeFromNib()
    {
        imageBrowserView.setValue(NSColor.darkGrayColor(), forKey: IKImageBrowserBackgroundColorKey)
        let newAttrs = imageBrowserView.valueForKey(IKImageBrowserCellsTitleAttributesKey)?.mutableCopy()
        newAttrs?.setValue(NSColor.whiteColor(), forKey: NSForegroundColorAttributeName)
        imageBrowserView.setValue(newAttrs, forKey: IKImageBrowserCellsTitleAttributesKey)

        thumbSizeSlider.floatValue = Preferences.thumbnailZoom
        imageBrowserView.setZoomValue(Preferences.thumbnailZoom)
    }

    @IBAction func openFolder(sender: AnyObject)
    {
        populateDirectoryView("/Users/goatboy/Pictures/Master/")
    }
}
