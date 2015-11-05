//
//  PeachMetadata
//

import WebKit

import Async
import RangicCore

extension PeachWindowController
{
    func clearAllMarkers()
    {
        invokeMapScript("removeAllMarkers()")
    }

    @IBAction func viewNormalMap(sender: AnyObject)
    {
        invokeMapScript("setMapLayer()")
    }

    @IBAction func viewSatelliteMap(sender: AnyObject)
    {
        invokeMapScript("setSatelliteLayer()")
    }

    @IBAction func viewDarkMap(sender: AnyObject)
    {
        invokeMapScript("setDarkLayer()")
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

        invokeMapScript("fitToBounds([[\(minLat), \(minLon)],[\(maxLat), \(maxLon)]])")

        let setId = "3"
        for m in mediaItems {
            if let location = m.location {
                let tooltip = "\(m.name)\\n\(m.keywordsString())"
                invokeMapScript("addMarker(\"\(m.url!.path!)\", \(setId), [\(location.latitude), \(location.longitude)], \"\(tooltip)\")")
            }
        }
    }

    func webView(sender: WebView!, didFinishLoadForFrame frame: WebFrame!)
    {
        let lat = 47.6220
        let lon = -122.335
        invokeMapScript("setCenter([\(lat), \(lon)], 12)")
    }

    func webView(webView: WebView!, didClearWindowObject windowObject: WebScriptObject!, forFrame frame: WebFrame!)
    {
        mapView.windowScriptObject.setValue(self, forKey: "MapThis")
    }

    func invokeMapScript(script: String) -> AnyObject?
    {
        Logger.info("Script: \(script)")
        return mapView.windowScriptObject.evaluateWebScript(script)
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
        let message = "Looking up \(locationJsonStr)"
        invokeMapScript("setPopup([\(lat), \(lon)], \"\(message)\")")

        Async.background {
            let placename = location.placenameAsString(.Minimal)
            Async.main {
                self.invokeMapScript("setPopup([\(lat), \(lon)], \"\(placename)\")")
            }
        }
    }

    func logMessage(message: String)
    {
        Logger.info("js log: \(message)")
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

        default:
            return nil
        }
    }

    override class func isSelectorExcludedFromWebScript(sel: Selector) -> Bool
    {
        return false
    }
}
