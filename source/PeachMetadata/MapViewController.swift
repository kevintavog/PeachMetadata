//
//  PeachMetadata
//

import WebKit

import RangicCore

extension PeachWindowController
{
    func clearAllMarkers()
    {
        invokeMapScript("removeAllMarkers()")
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
                invokeMapScript("addMarker(\(setId), [\(location.latitude), \(location.longitude)], \"\(tooltip)\")")
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
}
