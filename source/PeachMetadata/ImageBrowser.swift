//
//  PeachMetadata
//

import Quartz
import RangicCore

extension PeachWindowController
{
    @IBAction func updateThumbnailsize(sender: AnyObject)
    {
        Preferences.thumbnailZoom = thumbSizeSlider.floatValue
        imageBrowserView.setZoomValue(thumbSizeSlider.floatValue)
    }

    func populateImageView(folder: String)
    {
        mediaProvider.clear()
        mediaProvider.addFolder(folder)

        thumbnailItems = [ThumbnailViewItem]()
        for m in mediaProvider.mediaFiles {
            thumbnailItems.append(ThumbnailViewItem(mediaData: m))
        }

        imageBrowserView.reloadData()
    }

    // MARK: imageBrowserView data provider
    override func numberOfItemsInImageBrowser(browser: IKImageBrowserView!) -> Int
    {
        return thumbnailItems.count
    }

    override func imageBrowser(browser: IKImageBrowserView!, itemAtIndex index: Int) -> AnyObject!
    {
        return thumbnailItems[index]
    }

    // MARK: imageBrowserView Delegate
    override func imageBrowserSelectionDidChange(browser: IKImageBrowserView!)
    {
        Logger.warn("image selection changed")
        //        if imageBrowser.selectionIndexes().count == 1 {
        //            let media = mediaProvider?.mediaFiles[imageBrowser.selectionIndexes().firstIndex]
        //            let userInfo: [String: MediaData] = ["MediaData": media!]
        //            Notifications.postNotification(Notifications.Selection.MediaData, object: self, userInfo: userInfo)
        //        }
    }
}

public class ThumbnailViewItem : NSObject
{
    public let mediaData: MediaData


    init(mediaData: MediaData) {
        self.mediaData = mediaData
    }

    public override func imageUID() -> String! {
        return mediaData.url.path
    }

    public override func imageRepresentationType() -> String! {
        switch mediaData.type! {
        case .Image:
            return IKImageBrowserNSURLRepresentationType
        case .Video:
            return IKImageBrowserQTMoviePathRepresentationType
        default:
            return IKImageBrowserNSURLRepresentationType
        }
    }

    public override func imageRepresentation() -> AnyObject! {
        switch mediaData.type! {
        case .Image:
            return mediaData.url
        case .Video:
            return mediaData.url
        default:
            return mediaData.url
        }
    }
}