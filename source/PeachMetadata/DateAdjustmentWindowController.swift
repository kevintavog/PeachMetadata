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

    fileprivate var fileDate: Date!
    fileprivate var metadataDate: Date!
    let dateFormatter = DateFormatter()


    func newDate() -> Date?
    {
        return dateFormatter.date(from: newDateField.stringValue)
    }

    override func awakeFromNib()
    {
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        fileDateLabel.stringValue = dateFormatter.string(from: fileDate)
        metadataDateLabel.stringValue = dateFormatter.string(from: metadataDate)
    }

    func setDateValues(_ fileDate: Date, metadataDate: Date)
    {
        self.fileDate = fileDate
        self.metadataDate = metadataDate
    }

    @IBAction func adjustDates(_ sender: AnyObject)
    {
        let date = dateFormatter.date(from: newDateField.stringValue)
        if date == nil {
            let alert = NSAlert()
            alert.messageText = "Invalid date format: '\(newDateField.stringValue)'; must match '\(dateFormatter.dateFormat)'"
            alert.alertStyle = NSAlertStyle.warning
            alert.addButton(withTitle: "Close")
            alert.runModal()
            return
        }

        close()
        NSApplication.shared().stopModal(withCode: 1)
    }

    @IBAction func cancel(_ sender: AnyObject)
    {
        newDateField.stringValue = ""
        close()
        NSApplication.shared().stopModal(withCode: 0)
    }

    @IBAction func useFileDate(_ sender: AnyObject)
    {
        newDateField.stringValue = dateFormatter.string(from: fileDate)
    }

    @IBAction func useMetadataDate(_ sender: AnyObject)
    {
        newDateField.stringValue = dateFormatter.string(from: metadataDate)
    }
}
