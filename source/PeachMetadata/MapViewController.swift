//
//  PeachMetadata
//

import WebKit

import Async
import RangicCore

extension PeachWindowController
{
    func webView(_ sender: WebView!, contextMenuItemsForElement element: [AnyHashable: Any]!, defaultMenuItems: [Any]!) -> [Any]!
    {
        return nil
    }

    func clearAllMarkers()
    {
        let _ = mapView.invokeMapScript("removeAllMarkers()")
    }

    @IBAction func viewOpenStreetMap(_ sender: Any) {
        menuNormalMap?.state = .off
        menuDarkMap?.state = .off
        menuSatelliteMap?.state = .off
        menuOpenStreetMap?.state = .on
        let _ = mapView.invokeMapScript("setOpenStreetMapLayer()")
    }

    @IBAction func viewNormalMap(_ sender: AnyObject)
    {
        menuNormalMap?.state = .on
        menuDarkMap?.state = .off
        menuSatelliteMap?.state = .off
        menuOpenStreetMap?.state = .off
        let _ = mapView.invokeMapScript("setMapLayer()")
    }

    @IBAction func viewSatelliteMap(_ sender: AnyObject)
    {
        menuNormalMap?.state = .off
        menuDarkMap?.state = .off
        menuSatelliteMap?.state = .on
        menuOpenStreetMap?.state = .off
        let _ = mapView.invokeMapScript("setSatelliteLayer()")
    }

    @IBAction func viewDarkMap(_ sender: AnyObject)
    {
        menuNormalMap?.state = .off
        menuDarkMap?.state = .on
        menuSatelliteMap?.state = .off
        menuOpenStreetMap?.state = .off
        let _ = mapView.invokeMapScript("setDarkLayer()")
    }

    @IBAction func followSelectionOnMap(_ sender: AnyObject)
    {
        followSelectionOnMap = !followSelectionOnMap
        menuFollowSelectionOnMap?.state = followSelectionOnMap ? .on : .off
    }

    @objc func mapViewMediaSelected(_ notification: Notification)
    {
        if followSelectionOnMap {
            if let userInfo = notification.userInfo as? Dictionary<String,MediaData> {
                if let mediaData = userInfo["MediaData"] {
                    clearAllMarkers()
                    showMediaOnMap([mediaData])
                }
            }
        }
    }

    @IBAction func showImagesOnMap(_ sender: AnyObject)
    {
        Logger.info("Show images on map")
        clearAllMarkers()
        var mediaItems = selectedMediaItems()
        if mediaItems.count == 0 {
            mediaItems = [MediaData]()
            for (_, m) in mediaProvider.enumerated() {
                mediaItems.append(m)
            }
        }

        showMediaOnMap(mediaItems)
    }
    
    func showMediaOnMap(_ mediaItems: [MediaData])
    {
        var minLat = 90.0
        var maxLat = -90.0
        var minLon = 180.0
        var maxLon = -180.0

        var numberLocations = 0
        for m in mediaItems {
            if let location = m.location {
                numberLocations += 1
                minLat = min(minLat, location.latitude)
                maxLat = max(maxLat, location.latitude)
                minLon = min(minLon, location.longitude)
                maxLon = max(maxLon, location.longitude)
            }
        }

        if numberLocations == 0 {
            return
        }
        else if numberLocations == 1 {
            // Don't completely zoom in for a single image
            minLat -= 0.0015
            maxLat += 0.0015
            minLon -= 0.0015
            maxLon += 0.0015
        }

        let _ = mapView.invokeMapScript("fitToBounds([[\(minLat), \(minLon)],[\(maxLat), \(maxLon)]])")

        for m in mediaItems {
            if let location = m.location {
                let tooltip = "\(m.name!)\\n\(m.keywordsString())"
                let _ = mapView.invokeMapScript("addMarker(\"\(m.url!.path)\", '\(getId(m))', [\(location.latitude), \(location.longitude)], \"\(tooltip)\")")
            }
        }
    }

    func webView(_ sender: WebView!, didFinishLoadFor frame: WebFrame!)
    {
        let lat = 47.6220
        let lon = -122.335
        let _ = mapView.invokeMapScript("console = { log: function(msg) { MapThis.logMessage(msg); } }")
        let _ = mapView.invokeMapScript("setCenter([\(lat), \(lon)], 12)")
        setSensitiveLocationsOnMap()
    }

    func webView(_ webView: WebView!, didClearWindowObject windowObject: WebScriptObject!, for frame: WebFrame!)
    {
        mapView.windowScriptObject.setValue(self, forKey: "MapThis")
    }

    // A marker on the map was clicked - select the associated media item
    @objc func markerClicked(_ path: String)
    {
        for (index,m) in mediaProvider.enumerated() {
            if m.url!.path == path {
                imageBrowserView.setSelectionIndexes(NSIndexSet(index: index) as IndexSet?, byExtendingSelection: false)
                imageBrowserView.scrollIndexToVisible(index)
                break
            }
        }
    }

    // The map was clicked, show the full placename
    @objc func mapClicked(_ lat: Double, lon: Double)
    {
        Logger.info("mapClicked: \(lat), \(lon)")
        let location = Location(latitude: lat, longitude: lon)
        let locationJsonStr = location.toDms().replacingOccurrences(of: "\"", with: "\\\"")

        let setSensitiveLocationMessage =
            "<br><br>"
            + "<a onclick='toggleSensitiveLocation(\(lat), \(lon));return false' href='javascript:void(0);'>"
            + "Toggle sensitive location" +
            "</a>"
        let message = "Looking up \(locationJsonStr)" + setSensitiveLocationMessage
        let _ = mapView.invokeMapScript("setPopup([\(lat), \(lon)], \"\(message)\")")

        Async.background {
            let placename = location.placenameAsString(.none)
            Async.main {
                self.mapView.invokeMapScript("setPopup([\(lat), \(lon)], \"\(placename+setSensitiveLocationMessage)\")")
            }
        }
    }

    @objc func logMessage(_ message: String)
    {
        Logger.info("js log: \(message)")
    }

    @objc func toggleSensitiveLocation(_ lat: Double, lon: Double)
    {
        Logger.info("toggleSensitiveLocation: \(lat), \(lon)")

        let location = Location(latitude: lat, longitude: lon)
        if SensitiveLocations.sharedInstance.isSensitive(location) {
            SensitiveLocations.sharedInstance.remove(location)
        } else {
            SensitiveLocations.sharedInstance.add(location)
        }

        setSensitiveLocationsOnMap()
        loadThumbnails()
    }

    func setSensitiveLocationsOnMap()
    {
        let _ = mapView.invokeMapScript("removeAllSensitiveLocations()")

        for loc in SensitiveLocations.sharedInstance.locations {
            let _ = mapView.invokeMapScript("addSensitiveLocation([\(loc.latitude), \(loc.longitude)], \(Int(SensitiveLocations.sharedInstance.SensitiveDistanceInMeters)))")
        }
    }

    @objc func updateMarker(_ id: String, lat: Double, lon: Double)
    {
        Logger.info("updateMarker [\(id)] to \(lat), \(lon)")
        for (_, m) in mediaProvider.enumerated() {
            if String(getId(m)) == id {
                let filePaths = [(m.url?.path)!]
                updateLocations(Location(latitude: lat, longitude: lon), filePaths: filePaths)
                return
            }
        }

        Logger.info("Unable to find media associated with marker '\(id)', nothing updated")
    }

    override class func webScriptName(for sel: Selector) -> String?
    {
        switch sel {
        case #selector(PeachWindowController.logMessage(_:)):
            return "logMessage"

        case #selector(PeachWindowController.mapClicked(_:lon:)):
            return "mapClicked"

        case #selector(PeachWindowController.markerClicked(_:)):
            return "markerClicked"

        case #selector(PeachWindowController.updateMarker(_:lat:lon:)):
            return "updateMarker"

        case #selector(PeachWindowController.toggleSensitiveLocation(_:lon:)):
            return "toggleSensitiveLocation"

        default:
            return nil
        }
    }

    override class func isSelectorExcluded(fromWebScript sel: Selector) -> Bool
    {
        return false
    }

    func fixBadExif(_ mediaItems: [MediaData])
    {
        setStatus("Fixing bad EXIF for \(mediaItems.count) file(s)")
        let (imagePathList, videoPathList) = separateVideoList(mediaItems)
        
        Async.background {
            do {
                try ExifToolRunner.fixBadExif(imagePathList + videoPathList)
                
                for mediaData in mediaItems {
                    mediaData.reload()
                }
                
                Async.main {
                    self.reloadExistingMedia()
                    self.setStatus("Finished fixing bad EXIF for \(mediaItems.count) file(s)")
                }
            } catch let error {
                Async.main {
                    self.reloadExistingMedia()
                    self.setStatus("Fixing bad EXIF failed: \(error)")
                    PeachWindowController.showWarning("Fixing bad EXIF  failed: \(error)")
                }
            }
        }
    }
    

    func clearLocations(_ mediaItems: [MediaData])
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
                    self.reloadExistingMedia()
                    self.setStatus("Finished clearing location from \(mediaItems.count) file(s)")
                }
            } catch let error {
                Async.main {
                    self.reloadExistingMedia()
                    self.setStatus("Clearing file locations failed: \(error)")
                    PeachWindowController.showWarning("Clearing file locations failed: \(error)")
                }
            }
        }
        
    }

    // Callback invoked from MapWebView
    func updateLocations(_ location: Location, filePaths: [String])
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
                self.setStatus("Some files were not updated due to existing locations: \(skipList.joined(separator: ", "))")
                PeachWindowController.showWarning("Some files were not updated due to existing locations: \(skipList.joined(separator: ", "))")
            }
        }
    }

    func setFileLocation(_ filePaths: [String], location: Location, updateStatusText: Bool)
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
                    self.reloadExistingMedia()
                }

            } catch let error {
                Logger.error("Setting file location failed: \(error)")

                Async.main {
                    self.reloadExistingMedia()
                    self.setStatus("Setting file location failed: \(error)")
                    PeachWindowController.showWarning("Setting file location failed: \(error)")
                }
            }
        }
    }

    func separateVideoList(_ filePaths: [String]) -> (imagePathList:[String], videoPathList:[String])
    {
        var imagePathList = [String]()
        var videoPathList = [String]()

        for path in filePaths {
            if let mediaData = mediaProvider.itemFromFilePath(path) {
                if let mediaType = mediaData.type {
                    switch mediaType {
                    case SupportedMediaTypes.MediaType.image:
                        imagePathList.append(path)
                    case SupportedMediaTypes.MediaType.video:
                        videoPathList.append(path)
                    default:
                        Logger.warn("Ignoring unknown file type: \(path)")
                    }
                }
            }
        }

        return (imagePathList, videoPathList)
    }

    func separateVideoList(_ mediaItems: [MediaData]) -> (imagePathList:[String], videoPathList:[String])
    {
        var imagePathList = [String]()
        var videoPathList = [String]()

        for mediaData in mediaItems {
            if let mediaType = mediaData.type {
                switch mediaType {
                case SupportedMediaTypes.MediaType.image:
                    imagePathList.append(mediaData.url.path)
                case SupportedMediaTypes.MediaType.video:
                    videoPathList.append(mediaData.url.path)
                default:
                    Logger.warn("Ignoring unknown file type: \(mediaData.url.path)")
                }
            }
        }

        return (imagePathList, videoPathList)
    }

    func getId(_ mediaData: MediaData) -> Int
    {
        return mediaData.url!.hashValue
    }
}
