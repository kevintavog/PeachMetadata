//
//  DateAdjustmentWindowController.swift
//

import AppKit
import RangicCore

class DateAdjustmentWindowController : NSWindowController
{
    @IBOutlet weak var newDateField: NSTextField!
    @IBOutlet weak var fileDateLabel: NSTextField!
    @IBOutlet weak var metadataDateLabel: NSTextField!

    private var fileDate: NSDate!
    private var metadataDate: NSDate!
    let dateFormatter = NSDateFormatter()


    func newDate() -> NSDate?
    {
        return dateFormatter.dateFromString(newDateField.stringValue)
    }

    override func awakeFromNib()
    {
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        fileDateLabel.stringValue = dateFormatter.stringFromDate(fileDate)
        metadataDateLabel.stringValue = dateFormatter.stringFromDate(metadataDate)
    }

    func setDateValues(fileDate: NSDate, metadataDate: NSDate)
    {
        self.fileDate = fileDate
        self.metadataDate = metadataDate
    }

    @IBAction func adjustDates(sender: AnyObject)
    {
        let date = dateFormatter.dateFromString(newDateField.stringValue)
        if date == nil {
            let alert = NSAlert()
            alert.messageText = "Invalid date format: '\(newDateField.stringValue)'; must match '\(dateFormatter.dateFormat)'"
            alert.alertStyle = NSAlertStyle.WarningAlertStyle
            alert.addButtonWithTitle("Close")
            alert.runModal()
            return
        }

        close()
        NSApplication.sharedApplication().stopModalWithCode(1)
    }

    @IBAction func cancel(sender: AnyObject)
    {
        newDateField.stringValue = ""
        close()
        NSApplication.sharedApplication().stopModalWithCode(0)
    }

    @IBAction func useFileDate(sender: AnyObject)
    {
        newDateField.stringValue = dateFormatter.stringFromDate(fileDate)
    }

    @IBAction func useMetadataDate(sender: AnyObject)
    {
        newDateField.stringValue = dateFormatter.stringFromDate(metadataDate)
    }
}
