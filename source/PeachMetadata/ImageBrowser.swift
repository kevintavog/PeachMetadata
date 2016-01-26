//
//  PeachMetadata
//

import Foundation
import Quartz

import Async
import RangicCore

extension PeachWindowController
{
    static private let missingAttrs = [
        NSForegroundColorAttributeName : NSColor(deviceRed: 0.0, green: 0.7, blue: 0.7, alpha: 1.0),
        NSFontAttributeName : NSFont.labelFontOfSize(14)

    ]
    static private let badDataAttrs = [
        NSForegroundColorAttributeName : NSColor.orangeColor(),
        NSFontAttributeName : NSFont.labelFontOfSize(14)
    ]


    @IBAction func updateThumbnailsize(sender: AnyObject)
    {
        Preferences.thumbnailZoom = thumbSizeSlider.floatValue
        imageBrowserView.setZoomValue(thumbSizeSlider.floatValue)
    }

    func populateImageView(folder: String)
    {
        mediaProvider.clear()
        mediaProvider.addFolder(folder)

        for m in mediaProvider.mediaFiles {
            if let rotation = m.rotation {
                if rotation != 0 {
                    Logger.error("\(m.name) is rotated \(rotation)")
                }
            }
        }

        loadThumbnails()
    }

    func reloadExistingMedia()
    {
        mediaProvider.refresh()
        loadThumbnails()
    }

    func loadThumbnails()
    {
        thumbnailItems = [ThumbnailViewItem]()
        for m in mediaProvider.mediaFiles {
            thumbnailItems.append(ThumbnailViewItem(mediaData: m))
        }

        filterItems()
        setFolderStatus()
    }

    func isFilterActive() -> Bool
    {
        return statusLocationLabel.state != 0 || statusDateLabel.state != 0 || statusKeywordLabel.state != 0
    }

    func filterItems()
    {
        if isFilterActive() == false {
            filteredThumbnailItems = thumbnailItems
        } else {
            filteredThumbnailItems.removeAll()
            for thumb in thumbnailItems {

                if statusLocationLabel.state != 0 {
                    if let location = thumb.mediaData.location {
                        if SensitiveLocations.sharedInstance.isSensitive(location) {
                            filteredThumbnailItems.append(thumb)
                            continue
                        }
                    } else {
                        filteredThumbnailItems.append(thumb)
                        continue
                    }
                }

                if statusDateLabel.state != 0 {
                    if thumb.mediaData.doFileAndExifTimestampsMatch() == false {
                        filteredThumbnailItems.append(thumb)
                        continue
                    }
                }

                if statusKeywordLabel.state != 0 {
                    if thumb.mediaData.keywords == nil || thumb.mediaData.keywords?.count == 0 {
                        filteredThumbnailItems.append(thumb)
                    }
                }
            }
        }

        imageBrowserView.reloadData()
    }

    // MARK: imageBrowserView data provider
    override func numberOfItemsInImageBrowser(browser: IKImageBrowserView!) -> Int
    {
        return filteredThumbnailItems.count
    }

    override func imageBrowser(browser: IKImageBrowserView!, itemAtIndex index: Int) -> AnyObject!
    {
        return filteredThumbnailItems[index]
    }

    func selectedMediaItems() -> [MediaData]
    {
        var mediaItems = [MediaData]()
        for index in imageBrowserView.selectionIndexes() {
            mediaItems.append(mediaProvider.mediaFiles[index])
        }
        return mediaItems
    }

    // MARK: imageBrowserView Delegate
    override func imageBrowserSelectionDidChange(browser: IKImageBrowserView!)
    {
        let selectedItems = selectedMediaItems()

        switch imageBrowserView.selectionIndexes().count {
        case 0:
            setFolderStatus()
            postNoSelection()
        case 1:
            setSingleItemStatus(selectedItems.first!)
            postSelectedItem(selectedItems.first!)
        default:
            setMultiItemStatus(selectedItems, filesMessage: "files selected")
            postSelectedItem(selectedItems.first!)
        }

        
        do {
            if try selectedKeywords.save() {
                imageBrowserView.reloadData()
            }
        } catch let error {
            Logger.error("Failed saving keywords: \(error)")
            PeachWindowController.showWarning("Failed saving keywords: \(error)")
        }

        selectedKeywords = FilesAndKeywords(mediaItems: selectedItems)
        mediaKeywordsController.selectionChanged(selectedKeywords)
        allKeywordsController.selectionChanged(selectedKeywords)
    }

    func postSelectedItem(mediaData: MediaData)
    {
        let userInfo: [String: MediaData] = ["MediaData": mediaData]
        Notifications.postNotification(Notifications.Selection.MediaData, object: self, userInfo: userInfo)
    }

    func postNoSelection()
    {
        Notifications.postNotification(Notifications.Selection.MediaData, object: self, userInfo: nil)
    }

    func setStatus(message: String)
    {
        Logger.info("Status message changed: '\(message)'")
        statusLabel.stringValue = message
    }

    func setStatusMediaNumber(fileNumber: Int)
    {
        statusFileLabel.stringValue  = String(fileNumber)
    }

    func setStatusLocationInfo(count: Int, status: LocationStatus)
    {
        let message = String(count)
        var imageName = "location"
        if status == .SensitiveLocation {
            statusLocationLabel.attributedTitle = NSMutableAttributedString(string: message, attributes: PeachWindowController.badDataAttrs)
            imageName = "locationBad"
        } else if status == .MissingLocation {
            statusLocationLabel.attributedTitle = NSMutableAttributedString(string: message, attributes: PeachWindowController.missingAttrs)
            imageName = "locationMissing"
        } else {
            statusLocationLabel.title = message
        }

        statusLocationLabel.image = NSImage(imageLiteral: imageName)
    }

    func setStatusDateInfo(count: Int, status: DateStatus)
    {
        let message = String(count)
        var imageName = "timestamp"
        if status == .MismatchedDate {
            statusDateLabel.attributedTitle = NSMutableAttributedString(string: message, attributes: PeachWindowController.badDataAttrs)
            imageName = "timestampBad"
        } else {
            statusDateLabel.title = message
        }

        statusDateLabel.image = NSImage(imageLiteral: imageName)
    }

    func setStatusKeywordInfo(count: Int, status: KeywordStatus)
    {
        let message = String(count)
        var imageName = "keyword"
        if status == .NoKeyword {
            statusKeywordLabel.attributedTitle = NSMutableAttributedString(string: message, attributes: PeachWindowController.missingAttrs)
            imageName = "keywordMissing"
        } else {
            statusKeywordLabel.title = message
        }

        statusKeywordLabel.image = NSImage(imageLiteral: imageName)
    }

    func setSingleItemStatus(media: MediaData)
    {
        var locationString = media.locationString()
        var keywordsString = media.keywordsString()
        if media.keywords == nil || media.keywords.count == 0 {
            keywordsString = "< no keywords >"
        } else {
            keywordsString = media.keywords.joinWithSeparator(", ")
        }

        if media.location != nil && media.location.hasPlacename() {
            locationString = media.location.placenameAsString(Preferences.placenameFilter)
        }
        setStatus("\(media.name); \(locationString); \(keywordsString)")

        if let location = media.location {
            if !location.hasPlacename() {
                // There's a location, but the placename hasn't been resolved yet
                Async.background {
                    let placename = media.location.placenameAsString(Preferences.placenameFilter)
                    Async.main {
                        self.setStatus("\(media.name); \(placename); \(keywordsString)")
                    }
                }
            }
        }
    }

    func setMultiItemStatus(mediaItems: [MediaData], filesMessage: String)
    {
        var folderKeywords = Set<String>()
        for media in mediaItems {
            if let mediaKeywords = media.keywords {
                for k in mediaKeywords {
                    folderKeywords.insert(k)
                }
            }
        }

        let keywordsString = folderKeywords.joinWithSeparator(", ")
        setStatus("keywords: \(keywordsString)")
    }

    func setFolderStatus()
    {
        setMultiItemStatus(mediaProvider.mediaFiles, filesMessage: "files")
        setStatusMediaInfo()
    }

    func setStatusMediaInfo()
    {
        var numberMissingLocation = 0
        var numberWithSensitiveLocation = 0
        var numberWithMismatchedDate = 0
        var numberMissingKeyword = 0

        for media in mediaProvider.mediaFiles {
            if let location = media.location {
                if SensitiveLocations.sharedInstance.isSensitive(location) {
                    ++numberWithSensitiveLocation
                }

            } else {
                ++numberMissingLocation
            }

            if media.keywords == nil {
                ++numberMissingKeyword
            }

            if media.doFileAndExifTimestampsMatch() == false {
                ++numberWithMismatchedDate
            }
        }

        let mediaCount = mediaProvider.mediaFiles.count
        setStatusMediaNumber(mediaCount)

        if numberWithSensitiveLocation > 0 {
            setStatusLocationInfo(numberWithSensitiveLocation, status: .SensitiveLocation)
        }
        else if numberMissingLocation > 0 {
            setStatusLocationInfo(numberMissingLocation, status: .MissingLocation)
        } else {
            setStatusLocationInfo(mediaCount, status: .GoodLocation)
        }

        if numberWithMismatchedDate > 0 {
            setStatusDateInfo(numberWithMismatchedDate, status: .MismatchedDate)
        } else {
            setStatusDateInfo(mediaCount, status: .GoodDate)
        }

        if numberMissingKeyword > 0 {
            setStatusKeywordInfo(numberMissingKeyword, status: .NoKeyword)
        } else {
            setStatusKeywordInfo(mediaCount, status: .HasKeyword)
        }
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

public enum LocationStatus
{
    case MissingLocation
    case SensitiveLocation
    case GoodLocation
}

public enum DateStatus
{
    case GoodDate
    case MismatchedDate
}

public enum KeywordStatus
{
    case NoKeyword
    case HasKeyword
}