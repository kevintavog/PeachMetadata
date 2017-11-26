//
//  PeachMetadata
//

import AppKit
import RangicCore

extension PeachWindowController
{
    @IBAction func openFolder(_ sender: AnyObject)
    {
        let dialog = NSOpenPanel()

        dialog.canChooseFiles = false
        dialog.canChooseDirectories = true
        if 1 != dialog.runModal().rawValue || dialog.urls.count < 1 {
            return
        }

        NSDocumentController.shared.noteNewRecentDocumentURL(dialog.urls[0])

        let folderName = dialog.urls[0].path
        populateDirectoryView(folderName)
    }

    func populateDirectoryView(_ folderName: String)
    {
        Preferences.lastOpenedFolder = folderName
        rootDirectory = DirectoryTree(parent: nil, folder: folderName)
        directoryView.deselectAll(nil)
        directoryView.reloadData()
    }

    func selectDirectoryViewRow(_ folderName: String)
    {
        var bestRow = -1
        for row in 0..<directoryView.numberOfRows {
            let dt = directoryView.item(atRow: row) as! DirectoryTree
            if dt.folder == folderName {
                bestRow = row
                break
            }

            if folderName.lowercased().hasPrefix(dt.folder.lowercased()) {
                bestRow = row
            }
        }

        if bestRow >= 0 {
            directoryView.selectRowIndexes(IndexSet(integer: bestRow), byExtendingSelection: false)
            directoryView.scrollRowToVisible(bestRow)
        }
    }

    func outlineViewSelectionDidChange(_ notification: Notification)
    {
        let selectedItem = toTree(directoryView.item(atRow: directoryView.selectedRow) as AnyObject?)
        populateImageView(selectedItem.folder)
        Preferences.lastSelectedFolder = selectedItem.folder
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int
    {
        if rootDirectory == nil { return 0 }
        return toTree(item).subFolders.count
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool
    {
        return toTree(item).subFolders.count > 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject
    {
        return toTree(item).subFolders[index]
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueForTableColumn tableColumn: NSTableColumn?, byItem item: AnyObject?) -> AnyObject?
    {
        return toTree(item).relativePath as AnyObject?
    }

    func toTree(_ item: AnyObject?) -> DirectoryTree
    {
        if let dirTree = item as! DirectoryTree? {
            return dirTree
        }

        return rootDirectory!
    }
}

class DirectoryTree : NSObject
{
    let folder: String
    let relativePath: String
    fileprivate var _subFolders: [DirectoryTree]?


    init(parent: DirectoryTree!, folder: String)
    {
        self.folder = folder
        if parent == nil {
            relativePath = ""
        } else {
            relativePath = folder.relativePathFromBase(parent.folder)
        }
    }

    var subFolders: [DirectoryTree]
    {
        if _subFolders == nil {
            populateChildren()
        }
        return _subFolders!
    }

    fileprivate func populateChildren()
    {
        var folderEntries = [DirectoryTree]()

        if FileManager.default.fileExists(atPath: folder) {
            if let files = getFiles(folder) {
                for f in files {
                    var isFolder: ObjCBool = false
                    if FileManager.default.fileExists(atPath: f.path, isDirectory:&isFolder) && isFolder.boolValue {
                        folderEntries.append(DirectoryTree(parent: self, folder: f.path))
                    }
                }
            }
        }

        _subFolders = folderEntries
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
