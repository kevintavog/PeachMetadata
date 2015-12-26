//
//  MapWebView.swift
//

import WebKit

import RangicCore

public class MapWebView : WebView
{
    private var dropCallback: ((location: Location, filePaths: [String]) -> ())?


    func invokeMapScript(script: String) -> AnyObject?
    {
        Logger.info("Script: \(script)")
        return windowScriptObject.evaluateWebScript(script)
    }

    public func enableDragAndDrop(callback: (location: Location, filePaths: [String]) -> ())
    {
        dropCallback = callback
    }

    public override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation
    {
        if dropCallback == nil {
            return NSDragOperation.None
        }

        let list = filePaths(sender)
        return list.count > 0 ? NSDragOperation.Copy : NSDragOperation.None
    }

    public override func draggingUpdated(sender: NSDraggingInfo) -> NSDragOperation
    {
        if dropCallback == nil {
            return NSDragOperation.None
        }

        return NSDragOperation.Copy
    }

    public override func performDragOperation(sender: NSDraggingInfo) -> Bool
    {
        if dropCallback == nil {
            return false
        }

        var mapPoint = convertPoint(NSPoint(x: sender.draggingLocation().x, y: sender.draggingLocation().y), fromView: nil)
        mapPoint.y = self.frame.height - mapPoint.y
        if let ret = invokeMapScript("pointToLatLng([\(mapPoint.x), \(mapPoint.y)])") {
            let json = JSON(data:NSData(data: ret.dataUsingEncoding(NSUTF8StringEncoding)!))
            let latitude = json["lat"].doubleValue
            let longitude = json["lng"].doubleValue
            let location = Location(latitude: latitude, longitude: longitude)

            dropCallback!(location: location, filePaths: filePaths(sender))
            
            return true
        }
        return false
    }

    func filePaths(dragInfo: NSDraggingInfo) -> [String]
    {
        var list = [String]()
        if ((dragInfo.draggingPasteboard().types?.contains(NSFilenamesPboardType)) != nil) {
            if let dropData = dragInfo.draggingPasteboard().propertyListForType(NSFilenamesPboardType) as! NSArray? {
                for data in dropData {
                    let path = data as! String
                    if NSFileManager.defaultManager().fileExistsAtPath(path) {
                        list.append(path)
                    }
                }
            }
        }

        return list
    }
}