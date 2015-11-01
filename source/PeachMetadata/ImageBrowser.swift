//
//  PeachMetadata
//

import Foundation
import Quartz

import Async
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
        setFolderStatus()
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
        selectedMediaData.removeAll()
        var keywordList = [String]()
        switch imageBrowserView.selectionIndexes().count {
        case 0:
            setFolderStatus()
        case 1:
            let mediaData = mediaProvider.mediaFiles[imageBrowserView.selectionIndexes().firstIndex]
            keywordList = setSingleItemStatus(mediaData)
            selectedMediaData.append(mediaData)
        default:
            var mediaItems = [MediaData]()
            for index in imageBrowserView.selectionIndexes() {
                mediaItems.append(mediaProvider.mediaFiles[index])
            }
            keywordList = setMultiItemStatus(mediaItems, filesMessage: "files selected")
            selectedMediaData.appendContentsOf(mediaItems)
        }

        mediaKeywordsController.selectionChanged(keywordList)
    }

    func setStatus(message: String)
    {
        statusLabel.stringValue = message
    }

    func setSingleItemStatus(media: MediaData) -> [String]
    {
        var locationString = media.locationString()
        var keywordsString = media.keywordsString()
        var keywordsList = [String]()
        if media.keywords == nil || media.keywords.count == 0 {
            keywordsString = "< no keywords >"
        } else {
            keywordsList = media.keywords
        }

        if media.location != nil && media.location.hasPlacename() {
            locationString = media.location.placenameAsString(Preferences.placenameFilter)
        }
        setStatus("\(media.name); \(locationString); \(keywordsString)")

        if media.location == nil || media.location!.hasPlacename() {
            return keywordsList
        }

        // There's a location, but the placename hasn't been resolved yet
        Async.background {
            let placename = media.location.placenameAsString(Preferences.placenameFilter)
            Async.main {
                self.setStatus("\(media.name); \(placename); \(keywordsString)")
            }
        }

        return keywordsList
    }

    func setMultiItemStatus(mediaItems: [MediaData], filesMessage: String) -> [String]
    {
        var folderKeywords = Set<String>()
        var numberWithLocation = 0
        var numberWithKeyword = 0

        for media in mediaItems {
            if media.location != nil {
                ++numberWithLocation
            }

            if let mediaKeywords = media.keywords {
                ++numberWithKeyword
                for k in mediaKeywords {
                    folderKeywords.insert(k)
                }
            }
        }

        let keywordsString = folderKeywords.joinWithSeparator(", ")
        setStatus("\(mediaItems.count) \(filesMessage); \(numberWithLocation) with locations; \(numberWithKeyword) with keywords; '\(keywordsString)'")

        return folderKeywords.map({$0})
    }

    func setFolderStatus()
    {
        setMultiItemStatus(mediaProvider.mediaFiles, filesMessage: "files")
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