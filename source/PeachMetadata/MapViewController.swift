//
//  PeachMetadata
//

import WebKit

import Async
import RangicCore

extension PeachWindowController
{
    func webView(sender: WebView!, contextMenuItemsForElement element: [NSObject : AnyObject]!, defaultMenuItems: [AnyObject]!) -> [AnyObject]!
    {
        return nil
    }

    func clearAllMarkers()
    {
        mapView.invokeMapScript("removeAllMarkers()")
    }

    @IBAction func viewNormalMap(sender: AnyObject)
    {
        mapView.invokeMapScript("setMapLayer()")
    }

    @IBAction func viewSatelliteMap(sender: AnyObject)
    {
        mapView.invokeMapScript("setSatelliteLayer()")
    }

    @IBAction func viewDarkMap(sender: AnyObject)
    {
        mapView.invokeMapScript("setDarkLayer()")
    }

    @IBAction func showImagesOnMap(sender: AnyObject)
    {
        Logger.info("Show images on map")
        clearAllMarkers()
        var mediaItems = selectedMediaItems()
        if mediaItems.count == 0 {
            mediaItems = mediaProvider.mediaFiles
        }

        var minLat = 90.0
        var maxLat = -90.0
        var minLon = 180.0
        var maxLon = -180.0
        var hasLocations = false

        for m in mediaItems {
            if let location = m.location {
                hasLocations = true
                minLat = min(minLat, location.latitude)
                maxLat = max(maxLat, location.latitude)
                minLon = min(minLon, location.longitude)
                maxLon = max(maxLon, location.longitude)
            }
        }

        if !hasLocations {
            return
        }

        mapView.invokeMapScript("fitToBounds([[\(minLat), \(minLon)],[\(maxLat), \(maxLon)]])")

        let setId = "3"
        for m in mediaItems {
            if let location = m.location {
                let tooltip = "\(m.name)\\n\(m.keywordsString())"
                mapView.invokeMapScript("addMarker(\"\(m.url!.path!)\", \(setId), [\(location.latitude), \(location.longitude)], \"\(tooltip)\")")
            }
        }
    }

    func webView(sender: WebView!, didFinishLoadForFrame frame: WebFrame!)
    {
        let lat = 47.6220
        let lon = -122.335
        mapView.invokeMapScript("setCenter([\(lat), \(lon)], 12)")
        setSensitiveLocationsOnMap()
    }

    func webView(webView: WebView!, didClearWindowObject windowObject: WebScriptObject!, forFrame frame: WebFrame!)
    {
        mapView.windowScriptObject.setValue(self, forKey: "MapThis")
    }

    // A marker on the map was clicked - select the associated media item
    func markerClicked(path: String)
    {
        for (index,m) in mediaProvider.mediaFiles.enumerate() {
            if m.url!.path! == path {
                imageBrowserView.setSelectionIndexes(NSIndexSet(index: index), byExtendingSelection: false)
                imageBrowserView.scrollIndexToVisible(index)
                break
            }
        }
    }

    // The map was clicked, show the full placename
    func mapClicked(lat: NSNumber, lon: NSNumber)
    {
        Logger.info("mapClicked: \(lat.doubleValue), \(lon.doubleValue)")
        let location = Location(latitude: lat.doubleValue, longitude: lon.doubleValue)
        let locationJsonStr = location.toDms().stringByReplacingOccurrencesOfString("\"", withString: "\\\"")

        let setSensitiveLocationMessage =
            "<br><br>"
            + "<a onclick='toggleSensitiveLocation(\(lat.doubleValue), \(lon.doubleValue));return false' href='javascript:void(0);'>"
            + "Toggle sensitive location" +
            "</a>"
        let message = "Looking up \(locationJsonStr)" + setSensitiveLocationMessage
        mapView.invokeMapScript("setPopup([\(lat), \(lon)], \"\(message)\")")

        Async.background {
            let placename = location.placenameAsString(.None)
            Async.main {
                self.mapView.invokeMapScript("setPopup([\(lat), \(lon)], \"\(placename+setSensitiveLocationMessage)\")")
            }
        }
    }

    func logMessage(message: String)
    {
        Logger.info("js log: \(message)")
    }

    func toggleSensitiveLocation(lat: NSNumber, lon: NSNumber)
    {
        Logger.info("toggleSensitiveLocation: \(lat.doubleValue), \(lon.doubleValue)")

        let location = Location(latitude: lat.doubleValue, longitude: lon.doubleValue)
        if SensitiveLocations.sharedInstance.isSensitive(location) {
            SensitiveLocations.sharedInstance.remove(location)
        } else {
            SensitiveLocations.sharedInstance.add(location)
        }

        setSensitiveLocationsOnMap()
    }

    func setSensitiveLocationsOnMap()
    {
        mapView.invokeMapScript("removeAllSensitiveLocations()")

        for loc in SensitiveLocations.sharedInstance.locations {
            mapView.invokeMapScript("addSensitiveLocation([\(loc.latitude), \(loc.longitude)], \(Int(SensitiveLocations.sharedInstance.SensitiveDistanceInMeters)))")
        }
    }

    override class func webScriptNameForSelector(sel: Selector) -> String?
    {
        switch sel {
        case "logMessage:":
            return "logMessage"

        case "mapClicked:lon:":
            return "mapClicked"

        case "markerClicked:":
            return "markerClicked"

        case "toggleSensitiveLocation:lon:":
            return "toggleSensitiveLocation"

        default:
            return nil
        }
    }

    override class func isSelectorExcludedFromWebScript(sel: Selector) -> Bool
    {
        return false
    }

    func clearLocations(mediaItems: [MediaData])
    {
        setStatus("Clearing locations from \(mediaItems.count) file(s)")
        let (imagePathList, videoPathList) = separateVideoList(mediaItems)

        Async.background {
            do {
                try ExifToolRunner.clearFileLocations(imagePathList, videoFilePaths: videoPathList)

                for mediaData in mediaItems {
                    mediaData.location = nil
                }

                Async.main {
                    self.imageBrowserView.reloadData()
                    self.setStatus("Finished clearing location from \(mediaItems.count) file(s)")
                }
            } catch let error {
                Async.main {
                    self.setStatus("Clearing file locations failed: \(error)")
                }
            }
        }
        
    }

    // Callback invoked from MapWebView
    func updateLocations(location: Location, filePaths: [String])
    {
        var updateList = [String]()
        var skipList = [String]()
        for file in filePaths {
            if let mediaItem = mediaProvider.itemFromFilePath(file) {
                if mediaItem.location != nil && filePaths.count > 1 {
                    Logger.info("Not setting location on \(file), it has a location already")
                    skipList.append(file)
                } else {
                    updateList.append(file)
                }
            } else {
                Logger.warn("Unable to find entry for \(file)")
            }
        }

        // Update file locations...
        setFileLocation(updateList, location: location, updateStatusText: skipList.count < 1)

        if skipList.count > 0 {
            Async.main {
                self.setStatus("Some files were not updated due to existing locations: \(skipList.joinWithSeparator(", "))")
            }
        }
    }

    func setFileLocation(filePaths: [String], location: Location, updateStatusText: Bool)
    {
        if filePaths.count < 1 {
            Logger.warn("no files to update, no locations being updated")
            return
        }

        if updateStatusText {
            setStatus("Updating \(filePaths.count) file(s) to \(location.toDms())")
        }

        let (imagePathList, videoPathList) = separateVideoList(filePaths)

        Async.background {
            do {
                try ExifToolRunner.updateFileLocations(imagePathList, videoFilePaths: videoPathList, location: location)

                for file in filePaths {
                    if let mediaData = self.mediaProvider.itemFromFilePath(file) {
                        mediaData.location = location
                    }
                }

                Async.main {
                    self.imageBrowserView.reloadData()
                }

            } catch let error {
                Logger.error("Setting file location failed: \(error)")

                Async.main {
                    self.setStatus("Setting file location failed: \(error)")
                }
            }
        }
    }

    func separateVideoList(filePaths: [String]) -> (imagePathList:[String], videoPathList:[String])
    {
        var imagePathList = [String]()
        var videoPathList = [String]()

        for path in filePaths {
            if let mediaData = mediaProvider.itemFromFilePath(path) {
                if let mediaType = mediaData.type {
                    switch mediaType {
                    case SupportedMediaTypes.MediaType.Image:
                        imagePathList.append(path)
                    case SupportedMediaTypes.MediaType.Video:
                        videoPathList.append(path)
                    default:
                        Logger.warn("Ignoring unknown file type: \(path)")
                    }
                }
            }
        }

        return (imagePathList, videoPathList)
    }

    func separateVideoList(mediaItems: [MediaData]) -> (imagePathList:[String], videoPathList:[String])
    {
        var imagePathList = [String]()
        var videoPathList = [String]()

        for mediaData in mediaItems {
            if let mediaType = mediaData.type {
                switch mediaType {
                case SupportedMediaTypes.MediaType.Image:
                    imagePathList.append(mediaData.url.path!)
                case SupportedMediaTypes.MediaType.Video:
                    videoPathList.append(mediaData.url.path!)
                default:
                    Logger.warn("Ignoring unknown file type: \(mediaData.url.path)")
                }
            }
        }

        return (imagePathList, videoPathList)
    }

}
