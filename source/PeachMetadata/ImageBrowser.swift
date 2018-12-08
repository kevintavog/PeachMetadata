//
//  PeachMetadata
//

import Foundation
import Quartz

import Async
import RangicCore

extension PeachWindowController
{
    static fileprivate let missingAttrs = [
        NSAttributedStringKey.foregroundColor : NSColor(deviceRed: 0.0, green: 0.7, blue: 0.7, alpha: 1.0),
        NSAttributedStringKey.font : NSFont.labelFont(ofSize: 14)

    ]
    static fileprivate let badDataAttrs = [
        NSAttributedStringKey.foregroundColor : NSColor.orange,
        NSAttributedStringKey.font : NSFont.labelFont(ofSize: 14)
    ]


    @IBAction func updateThumbnailsize(_ sender: AnyObject)
    {
        Preferences.thumbnailZoom = thumbSizeSlider.floatValue
        imageBrowserView.setZoomValue(thumbSizeSlider.floatValue)
    }

    func populateImageView(_ folder: String)
    {
        mediaProvider.clear()
        mediaProvider.addFolder(folder)

//        for (_, m) in mediaProvider.enumerated() {
//            if let rotation = m.rotation {
//                if rotation != 0 {
//                    Logger.error("\(m.name!) is rotated \(rotation)")
//                }
//            }
//        }

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
        for (_, m) in mediaProvider.enumerated() {
            thumbnailItems.append(ThumbnailViewItem(mediaData: m))
        }

        filterItems()
        setFolderStatus()
    }

    func isFilterActive() -> Bool
    {
        return statusLocationLabel.state != .off || statusDateLabel.state != .off || statusKeywordLabel.state != .off
    }

    func filterItems()
    {
        if isFilterActive() == false {
            filteredThumbnailItems = thumbnailItems
        } else {
            filteredThumbnailItems.removeAll()
            for thumb in thumbnailItems {

                if statusLocationLabel.state != .off {
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

                if statusDateLabel.state != .off {
                    if thumb.mediaData.doFileAndExifTimestampsMatch() == false {
                        filteredThumbnailItems.append(thumb)
                        continue
                    }
                }

                if statusKeywordLabel.state != .off {
                    if thumb.mediaData.keywords == nil || thumb.mediaData.keywords?.count == 0 {
                        filteredThumbnailItems.append(thumb)
                    }
                }
            }
        }

        imageBrowserView.reloadData()
    }

    // MARK: imageBrowserView data provider
    override func numberOfItems(inImageBrowser browser: IKImageBrowserView!) -> Int
    {
        return filteredThumbnailItems.count
    }

    override func imageBrowser(_ browser: IKImageBrowserView!, itemAt index: Int) -> Any!
    {
        return filteredThumbnailItems[index]
    }

    func selectedMediaItems() -> [MediaData]
    {
        var mediaItems = [MediaData]()
        for index in imageBrowserView.selectionIndexes() {
            mediaItems.append(mediaProvider.getMedia(index)!)
        }
        return mediaItems
    }

    // MARK: imageBrowserView Delegate
    override func imageBrowserSelectionDidChange(_ browser: IKImageBrowserView!)
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

    func postSelectedItem(_ mediaData: MediaData)
    {
        let userInfo: [String: MediaData] = ["MediaData": mediaData]
        Notifications.postNotification(Notifications.Selection.MediaData, object: self, userInfo: userInfo)
    }

    func postNoSelection()
    {
        Notifications.postNotification(Notifications.Selection.MediaData, object: self, userInfo: nil)
    }

    func setStatus(_ message: String)
    {
        Logger.info("Status message changed: '\(message)'")
        statusLabel.stringValue = message
    }

    func setStatusMediaNumber(_ fileNumber: Int)
    {
        statusFileLabel.stringValue  = String(fileNumber)
    }

    func setStatusLocationInfo(_ count: Int, status: LocationStatus)
    {
        let message = String(count)
        var imageName = "location"
        if status == .sensitiveLocation {
            statusLocationLabel.attributedTitle = NSMutableAttributedString(string: message, attributes: PeachWindowController.badDataAttrs)
            imageName = "locationBad"
        } else if status == .missingLocation {
            statusLocationLabel.attributedTitle = NSMutableAttributedString(string: message, attributes: PeachWindowController.missingAttrs)
            imageName = "locationMissing"
        } else {
            statusLocationLabel.title = message
        }

        statusLocationLabel.image = NSImage(imageLiteralResourceName: imageName)
    }

    func setStatusDateInfo(_ count: Int, status: DateStatus)
    {
        let message = String(count)
        var imageName = "timestamp"
        if status == .mismatchedDate {
            statusDateLabel.attributedTitle = NSMutableAttributedString(string: message, attributes: PeachWindowController.badDataAttrs)
            imageName = "timestampBad"
        } else {
            statusDateLabel.title = message
        }

        statusDateLabel.image = NSImage(imageLiteralResourceName: imageName)
    }

    func setStatusKeywordInfo(_ count: Int, status: KeywordStatus)
    {
        let message = String(count)
        var imageName = "keyword"
        if status == .noKeyword {
            statusKeywordLabel.attributedTitle = NSMutableAttributedString(string: message, attributes: PeachWindowController.missingAttrs)
            imageName = "keywordMissing"
        } else {
            statusKeywordLabel.title = message
        }

        statusKeywordLabel.image = NSImage(imageLiteralResourceName: imageName)
    }

    func setSingleItemStatus(_ media: MediaData)
    {
        var locationString = media.locationString()
        var keywordsString = media.keywordsString()
        if media.keywords == nil || media.keywords.count == 0 {
            keywordsString = "< no keywords >"
        } else {
            keywordsString = media.keywords.joined(separator: ", ")
        }

        if media.location != nil && media.location.hasPlacename() {
            locationString = media.location.placenameAsString(Preferences.placenameFilter)
        }
        setStatus(String("\(media.name!); \(locationString); \(keywordsString)"))

        if let location = media.location {
            if !location.hasPlacename() {
                // There's a location, but the placename hasn't been resolved yet
                Async.background {
                    let placename = media.location.placenameAsString(Preferences.placenameFilter)
                    Async.main {
                        self.setStatus("\(media.name!); \(placename); \(keywordsString)")
                    }
                }
            }
        }
    }

    func setMultiItemStatus(_ mediaItems: [MediaData], filesMessage: String)
    {
        var folderKeywords = Set<String>()
        for media in mediaItems {
            if let mediaKeywords = media.keywords {
                for k in mediaKeywords {
                    folderKeywords.insert(k)
                }
            }
        }

        let keywordsString = folderKeywords.joined(separator: ", ")
        setStatus("keywords: \(keywordsString)")
    }

    func setFolderStatus()
    {
        var mediaFiles = [MediaData]()
        for (_, m) in mediaProvider.enumerated() {
            mediaFiles.append(m)
        }

        setMultiItemStatus(mediaFiles, filesMessage: "files")
        setStatusMediaInfo()
    }

    func setStatusMediaInfo()
    {
        var numberMissingLocation = 0
        var numberWithSensitiveLocation = 0
        var numberWithMismatchedDate = 0
        var numberMissingKeyword = 0

        for (_, media) in mediaProvider.enumerated() {
            if let location = media.location {
                if SensitiveLocations.sharedInstance.isSensitive(location) {
                    numberWithSensitiveLocation += 1
                }

            } else {
                numberMissingLocation += 1
            }

            if media.keywords == nil {
                numberMissingKeyword += 1
            }

            if media.doFileAndExifTimestampsMatch() == false {
                numberWithMismatchedDate += 1
            }
        }

        let mediaCount = mediaProvider.mediaCount
        setStatusMediaNumber(mediaCount)

        if numberWithSensitiveLocation > 0 {
            setStatusLocationInfo(numberWithSensitiveLocation, status: .sensitiveLocation)
        }
        else if numberMissingLocation > 0 {
            setStatusLocationInfo(numberMissingLocation, status: .missingLocation)
        } else {
            setStatusLocationInfo(mediaCount, status: .goodLocation)
        }

        if numberWithMismatchedDate > 0 {
            setStatusDateInfo(numberWithMismatchedDate, status: .mismatchedDate)
        } else {
            setStatusDateInfo(mediaCount, status: .goodDate)
        }

        if numberMissingKeyword > 0 {
            setStatusKeywordInfo(numberMissingKeyword, status: .noKeyword)
        } else {
            setStatusKeywordInfo(mediaCount, status: .hasKeyword)
        }
    }
}

open class ThumbnailViewItem : NSObject
{
    public let mediaData: MediaData


    init(mediaData: MediaData) {
        self.mediaData = mediaData
    }

    open override func imageUID() -> String! {
        return mediaData.url.path
    }

    open override func imageRepresentationType() -> String! {
        switch mediaData.type! {
        case .image:
            return IKImageBrowserNSURLRepresentationType
        case .video:
            return IKImageBrowserQTMoviePathRepresentationType
        default:
            return IKImageBrowserNSURLRepresentationType
        }
    }

    open override func imageRepresentation() -> Any! {
        switch mediaData.type! {
        case .image:
            return mediaData.url
        case .video:
            return mediaData.url
        default:
            return mediaData.url
        }
    }
}

public enum LocationStatus
{
    case missingLocation
    case sensitiveLocation
    case goodLocation
}

public enum DateStatus
{
    case goodDate
    case mismatchedDate
}

public enum KeywordStatus
{
    case noKeyword
    case hasKeyword
}
