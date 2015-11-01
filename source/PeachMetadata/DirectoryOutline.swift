//
//  PeachMetadata
//

import AppKit
import RangicCore

extension PeachWindowController
{
    @IBAction func openFolder(sender: AnyObject)
    {
        let dialog = NSOpenPanel()

        dialog.canChooseFiles = false
        dialog.canChooseDirectories = true
        if 1 != dialog.runModal() || dialog.URLs.count < 1 {
            return
        }

        NSDocumentController.sharedDocumentController().noteNewRecentDocumentURL(dialog.URLs[0])

        let folderName = dialog.URLs[0].path!
        Preferences.lastOpenedFolder = folderName
        populateDirectoryView(folderName)
    }

    func populateDirectoryView(folderName: String)
    {
        rootDirectory = DirectoryTree(parent: nil, folder: folderName)
        directoryView.reloadData()
    }

    func selectDirectoryViewRow(folderName: String)
    {
        var bestRow = -1
        for row in 0..<directoryView.numberOfRows {
            let dt = directoryView.itemAtRow(row) as! DirectoryTree
            if dt.folder == folderName {
                bestRow = row
                break
            }

            if folderName.lowercaseString.hasPrefix(dt.folder.lowercaseString) {
                bestRow = row
            }
        }

        if bestRow >= 0 {
            directoryView.selectRowIndexes(NSIndexSet(index: bestRow), byExtendingSelection: false)
        }
    }

    func outlineViewSelectionDidChange(notification: NSNotification)
    {
        let selectedItem = toTree(directoryView.itemAtRow(directoryView.selectedRow))
        Logger.info("Folder selection changed: \(selectedItem.folder)")
        populateImageView(selectedItem.folder)
        Preferences.lastSelectedFolder = selectedItem.folder
    }

    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int
    {
        if rootDirectory == nil { return 0 }
        return toTree(item).subFolders.count
    }

    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool
    {
        return toTree(item).subFolders.count > 0
    }

    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject
    {
        return toTree(item).subFolders[index]
    }

    func outlineView(outlineView: NSOutlineView, objectValueForTableColumn tableColumn: NSTableColumn?, byItem item: AnyObject?) -> AnyObject?
    {
        return toTree(item).relativePath
    }

    func toTree(item: AnyObject?) -> DirectoryTree
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
    private var _subFolders: [DirectoryTree]?


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

    private func populateChildren()
    {
        var folderEntries = [DirectoryTree]()

        if NSFileManager.defaultManager().fileExistsAtPath(folder) {
            if let files = getFiles(folder) {
                for f in files {
                    var isFolder: ObjCBool = false
                    if NSFileManager.defaultManager().fileExistsAtPath(f.path!, isDirectory:&isFolder) && isFolder {
                        folderEntries.append(DirectoryTree(parent: self, folder: f.path!))
                    }
                }
            }
        }

        _subFolders = folderEntries
    }

    private func getFiles(folderName: String) -> [NSURL]?
    {
        do {
            return try NSFileManager.defaultManager().contentsOfDirectoryAtURL(
                NSURL(fileURLWithPath: folderName),
                includingPropertiesForKeys: nil,
                options:NSDirectoryEnumerationOptions.SkipsHiddenFiles)
        }
        catch let error {
            Logger.error("Failed getting files in \(folderName): \(error)")
            return nil
        }
    }
}