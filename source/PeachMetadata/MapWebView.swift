//
//  MapWebView.swift
//

import WebKit
import SwiftyJSON

import RangicCore

open class MapWebView : WebView
{
    // In Swift 4, 'NSPasteboard.PasteboardType.fileURL' is available, but seems to be OSX 10.13 only - use this as a workaround
    let FilenamesPboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")

    
    fileprivate var dropCallback: ((_ location: Location, _ filePaths: [String]) -> ())?

    func invokeMapScript(_ script: String) -> AnyObject?
    {
        Logger.info("Script: \(script)")
        return windowScriptObject.evaluateWebScript(script) as AnyObject?
    }

    open func enableDragAndDrop(_ callback: @escaping (_ location: Location, _ filePaths: [String]) -> ())
    {
        dropCallback = callback
    }

    open override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation
    {
        if dropCallback == nil {
            return NSDragOperation()
        }

        let list = filePaths(sender)
        return list.count > 0 ? NSDragOperation.copy : NSDragOperation()
    }

    open override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation
    {
        if dropCallback == nil {
            return NSDragOperation()
        }

        return NSDragOperation.copy
    }

    open override func performDragOperation(_ sender: NSDraggingInfo) -> Bool
    {
        if dropCallback == nil {
            return false
        }

        var mapPoint = convert(NSPoint(x: sender.draggingLocation().x, y: sender.draggingLocation().y), from: nil)
        mapPoint.y = self.frame.height - mapPoint.y
        if let ret = invokeMapScript("pointToLatLng([\(mapPoint.x), \(mapPoint.y)])") {
            let resultString = ret as! String
            if let json = try? JSON(data:Data(resultString.data(using: String.Encoding.utf8)!)) {
                let latitude = json["lat"].doubleValue
                let longitude = json["lng"].doubleValue
                let location = Location(latitude: latitude, longitude: longitude)

                dropCallback!(location, filePaths(sender))
                
                return true
            }
        }
        return false
    }

    func filePaths(_ dragInfo: NSDraggingInfo) -> [String]
    {
        var list = [String]()
        if ((dragInfo.draggingPasteboard().types?.contains(FilenamesPboardType)) != nil) {
            if let dropData = dragInfo.draggingPasteboard().propertyList(forType: FilenamesPboardType) as! NSArray? {
                for data in dropData {
                    let path = data as! String
                    if FileManager.default.fileExists(atPath: path) {
                        list.append(path)
                    }
                }
            }
        }

        return list
    }
}
