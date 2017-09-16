//
//  ImportMediaWindowsController.swift
//

import AppKit
import Async
import RangicCore

class ImportMediaWindowsController : NSWindowController, NSTableViewDataSource
{
    static fileprivate let missingAttrs = [
        NSForegroundColorAttributeName : NSColor(deviceRed: 0.0, green: 0.7, blue: 0.7, alpha: 1.0),
        NSFontAttributeName : NSFont.labelFont(ofSize: 14)

    ]
    static fileprivate let badDataAttrs = [
        NSForegroundColorAttributeName : NSColor.orange,
        NSFontAttributeName : NSFont.labelFont(ofSize: 14)
    ]

    static fileprivate func applyAttributes(_ text: String, attributes: [String:AnyObject]) -> NSAttributedString
    {
        let fullRange = NSRange(location: 0, length: text.characters.count)
        let attributeString = NSMutableAttributedString(string: text)
        for attr in attributes {
            attributeString.addAttribute(attr.0, value: attr.1, range: fullRange)
        }
        return attributeString
    }

    @IBOutlet var progressController: ImportProgressWindowsController!

    fileprivate let OriginalTableTag = 1
    fileprivate let ExportedTableTag = 2
    fileprivate let WarningsTableTag = 3

    fileprivate let FilenameColumnIdentifier = "Filename"
    fileprivate let TimestampColumnIdentifier = "Timestamp"
    fileprivate let TimestampStatusColumnIdentifier = "TimestampStatus"
    fileprivate let LocationColumnIdentifier = "Location"
    fileprivate let LocationStatusColumnIdentifier = "LocationStatus"



    @IBOutlet weak var importFolderLabel: NSTextField!
    @IBOutlet weak var exportFolderLabel: NSTextField!
    @IBOutlet weak var importTable: NSTableView!
    @IBOutlet weak var exportTable: NSTableView!

    fileprivate var firstDidBecomeKey = true
    fileprivate var importFolderName: String?
    var exportFolderName: String?
    var yearForMaster: String?
    var originalMediaData = [MediaData]()
    var exportedMediaData = [MediaData]()
    var warnings = [String]()


    // Must be called to setup data - returns false if the import is not supported
    func setImportFolder(_ path: String) -> Bool
    {
        Logger.info("importMedia from \(path)")
        if loadFileData(path) {
            importFolderName = path
            return true
        }
        return false
    }


    override func awakeFromNib()
    {
        importFolderLabel.stringValue = importFolderName!
        exportFolderLabel.stringValue = exportFolderName!
    }

    func windowDidBecomeKey(_ notification: Notification)
    {
        if firstDidBecomeKey {
            exportFolderLabel.currentEditor()?.moveToEndOfLine(self)
            firstDidBecomeKey = false
        }
    }

    @IBAction func importMedia(_ sender: AnyObject)
    {
        if exportFolderName == exportFolderLabel.stringValue {
            PeachWindowController.showWarning("The destination folder name must be different from the date.\r\r Currently: '\(exportFolderLabel.stringValue)'")
            return
        }

        // Confirm the folder name has been changed (isn't date only); allow to pass if OK
        // How to handle if destination folder already exists? Perhaps confirm that a merge is what's desired
        let picturesFolder = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!.path
        let folder = NSString.path(withComponents: [picturesFolder, "Master", yearForMaster!, exportFolderLabel.stringValue])

        if !warnings.isEmpty {
            if !PeachWindowController.askQuestion("Do you want to import with \(warnings.count) warning(s)?") {
                return
            }
        }

        close()
        progressController.start(importFolderName!, destinationFolder: folder, originalMediaData: originalMediaData, exportedMediaData: exportedMediaData)

        NSApplication.shared().stopModal(withCode: 1)
    }

    @IBAction func cancel(_ sender: AnyObject)
    {
        close()
        NSApplication.shared().stopModal(withCode: 0)
    }


    func numberOfRows(in tableView: NSTableView) -> Int
    {
        switch tableView.tag {
        case OriginalTableTag:
            return originalMediaData.count
        case ExportedTableTag:
            return exportedMediaData.count
        case WarningsTableTag:
            return warnings.count
        default:
            Logger.error("Unsupported tableView: \(tableView.tag)")
            return 0
        }
    }

    // If @nonobjc is added here, per the warning, then nothing shows up in the tables...
    public func tableView(_ tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView?
    {
        let cell = tableView.make(withIdentifier: tableColumn!.identifier, owner: self) as! NSTableCellView

        var media: MediaData!
        switch tableView.tag {
        case OriginalTableTag:
            media = originalMediaData[row]
        case ExportedTableTag:
            media = exportedMediaData[row]
        case WarningsTableTag:
            cell.textField?.stringValue = warnings[row]
            return cell
        default:
            Logger.error("Unsupported tableView: \(tableView.tag)")
        }

        if let data = media {
            let missingLocation = data.location == nil
            let sensitiveLocation = !missingLocation && SensitiveLocations.sharedInstance.isSensitive(data.location!)

            switch tableColumn!.identifier {
            case FilenameColumnIdentifier:
                cell.textField?.stringValue = data.name

            case TimestampColumnIdentifier:
                if data.doFileAndExifTimestampsMatch() {
                    cell.textField?.stringValue = data.formattedTime()
                } else {
                    cell.textField?.attributedStringValue = ImportMediaWindowsController.applyAttributes(data.formattedTime(), attributes: ImportMediaWindowsController.badDataAttrs)
                }

            case TimestampStatusColumnIdentifier:
                if data.doFileAndExifTimestampsMatch() {
                    cell.imageView?.image = nil
                } else {
                    cell.imageView?.image = NSImage(imageLiteralResourceName: "timestampBad")
                }

            case LocationColumnIdentifier:
                if missingLocation {
                    cell.textField?.attributedStringValue = ImportMediaWindowsController.applyAttributes("< missing >", attributes: ImportMediaWindowsController.missingAttrs)
                } else if sensitiveLocation {
                    cell.textField?.attributedStringValue = ImportMediaWindowsController.applyAttributes(data.locationString(), attributes: ImportMediaWindowsController.badDataAttrs)
                } else {
                    cell.textField?.stringValue = data.locationString()
                }

            case LocationStatusColumnIdentifier:
                if missingLocation {
                    cell.imageView?.image = NSImage(imageLiteralResourceName: "locationMissing")
                } else if sensitiveLocation {
                    cell.imageView?.image = NSImage(imageLiteralResourceName: "locationBad")
                } else {
                    cell.imageView?.image = nil
                }

            default:
                Logger.error("Unsupported column \(tableColumn!.identifier)")
            }
        }

        return cell;
    }

    func loadFileData(_ path: String) -> Bool
    {
        // Get subfolders - must have ONLY 'Exported'
        let (folders, originalFiles) = getFoldersAndFiles(path)
        if folders.count != 1 {
            PeachWindowController.showWarning("Import supports only a single folder, found \(folders.count)")
            return false
        }

        if folders.first!.lastPathComponent != "Exported" {
            PeachWindowController.showWarning("Import requires a folder named 'Exported'; found '\(String(describing: folders.first))'")
            return false
        }

        let (exportedFolders, exportedFiles) = getFoldersAndFiles(folders.first!.path)
        if exportedFolders.count != 0 {
            PeachWindowController.showWarning("The 'Exported' has at least one subfolder - but shouldn't have any")
            return false
        }

        var hasVideos = false
        var unsupportedFiles = [String]()
        for original in originalFiles {
            let mediaType = SupportedMediaTypes.getType(original)
            if mediaType != .unknown {
                if mediaType == .video {
                    hasVideos = true
                }
                originalMediaData.append(FileMediaData.create(original, mediaType: mediaType))
            } else {
                unsupportedFiles.append(original.lastPathComponent)
            }
        }
        for exported in exportedFiles {
            let mediaType = SupportedMediaTypes.getType(exported)
            if mediaType != .unknown {
                let mediaData = FileMediaData.create(exported, mediaType: mediaType)
                exportedMediaData.append(mediaData)
                if !mediaData.doFileAndExifTimestampsMatch() {
                    let _ = mediaData.setFileDateToExifDate()
                }
            } else {
                unsupportedFiles.append(exported.lastPathComponent)
            }
        }

        if unsupportedFiles.count != 0 {
            PeachWindowController.showWarning("Found unsupported files: \(unsupportedFiles.joined(separator: ", "))")
            return false
        }

        if exportedMediaData.count == 0 && !hasVideos {
            PeachWindowController.showWarning("No exported files were found")
            return false
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let yearDateFormatter = DateFormatter()
        yearDateFormatter.dateFormat = "yyyy"

        if exportedMediaData.count > 0 {
            exportFolderName = dateFormatter.string(from: exportedMediaData.first!.timestamp!) + " "
            yearForMaster = yearDateFormatter.string(from: exportedMediaData.first!.timestamp!)
        } else {
            exportFolderName = dateFormatter.string(from: originalMediaData.first!.timestamp!) + " "
            yearForMaster = yearDateFormatter.string(from: originalMediaData.first!.timestamp!)
        }


        let importer = ImportLightroomExport(originalMediaData: originalMediaData, exportedMediaData: exportedMediaData)
        warnings = importer.findWarnings();

        return true
    }

    // Return the folders and files from a given path
    func getFoldersAndFiles(_ path: String) -> (folders: [URL], files: [URL])
    {
        var folders = [URL]()
        var files = [URL]()

        if let allChildren = getFiles(path) {
            for child in allChildren {
                var isFolder: ObjCBool = false
                if FileManager.default.fileExists(atPath: child.path, isDirectory:&isFolder) && isFolder.boolValue {
                    folders.append(child)
                } else {
                    files.append(child)
                }
            }
        }

        return (folders, files)
    }

    fileprivate func getFiles(_ folderName: String) -> [URL]?
    {
        do {
            return try FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: folderName),
                includingPropertiesForKeys: nil,
                options:FileManager.DirectoryEnumerationOptions.skipsHiddenFiles)
        }
        catch let error {
            Logger.error("Failed getting files in \(folderName): \(error)")
            return nil
        }
    }
}
