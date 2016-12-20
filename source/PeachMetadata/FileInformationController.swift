//
//  Radish
//

import AppKit

import RangicCore


class FileInformationController : NSViewController
{
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var panel: NSPanel!

    fileprivate var currentMediaData: MediaData?


    override func awakeFromNib()
    {
        tableView.backgroundColor = NSColor.clear
        Notifications.addObserver(self, selector: #selector(FileInformationController.fileSelected(_:)), name: Notifications.Selection.MediaData, object: nil)
        Notifications.addObserver(self, selector: #selector(FileInformationController.detailsUpdated(_:)), name: MediaProvider.Notifications.DetailsAvailable, object: nil)
    }


    // MARK: actions
    func toggleVisibility()
    {
        if panel.isVisible {
            panel.orderOut(self)
        }
        else {
            updateView()
            panel.makeKeyAndOrderFront(self)
        }
    }


    // MARK: Notification handlers
    func fileSelected(_ notification: Notification)
    {
        currentMediaData = nil
        if let userInfo = notification.userInfo as? Dictionary<String,MediaData> {
            if let mediaData = userInfo["MediaData"] {
                currentMediaData = mediaData
            }
        }

        if panel.isVisible {
            updateView()
        }
    }

    func detailsUpdated(_ notification: Notification)
    {
        if let notObject = notification.object as! MediaData? {
            if notObject === currentMediaData {
                tableView.reloadData()
            }
        }
    }

    func updateView()
    {
        if let name = currentMediaData?.name {
            panel.title = "File Information - \(name)"
        }
        else {
            panel.title = "File Information"
        }

        tableView.reloadData()
    }

    // MARK: table view data
    func numberOfRowsInTableView(_ tv: NSTableView) -> Int
    {
        return currentMediaData == nil ? 0 : (currentMediaData?.details.count)!
    }

    func tableView(_ tv: NSTableView, objectValueForTableColumn: NSTableColumn?, row: Int) -> String
    {
        let detail = currentMediaData?.details[row]
        switch (objectValueForTableColumn!.dataCell as AnyObject).tag {
        case 1:
            return detail?.category == nil ? "" : (detail?.category)!
        case 2:
            return detail?.name == nil ? "" : (detail?.name)!
        case 3:
            return detail?.value == nil ? "" : (detail?.value)!
        default:
            Logger.error("Unhandled file information tag: \((objectValueForTableColumn!.dataCell as AnyObject).tag)")
            return ""
        }
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool
    {
        return currentMediaData?.details[row].category != nil
    }

    func tableView(_ tableView: NSTableView, willDisplayCell cell: AnyObject, forTableColumn tableColumn: NSTableColumn?, row: Int)
    {
        if let textCell = cell as? NSTextFieldCell {
            textCell.textColor = NSColor.white
            textCell.drawsBackground = false

            // Force a redraw, otherwise the color for column 1 doesn't update properly
            textCell.stringValue = textCell.stringValue
        }
    }
}
