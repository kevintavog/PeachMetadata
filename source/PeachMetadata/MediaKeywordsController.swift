//
//  PeachMetadata
//

import AppKit
import RangicCore

class MediaKeywordsTableController : NSObject, NSTableViewDelegate, NSTableViewDataSource
{
    let tableView: NSTableView
    var filesAndKeywords: FilesAndKeywords


    init(tableView: NSTableView)
    {
        self.tableView = tableView
        filesAndKeywords = FilesAndKeywords()
    }

    func keywordToggled(index: Int)
    {
        let keyword = filesAndKeywords.uniqueKeywords[index]
        filesAndKeywords.removeKeyword(keyword)
    }

    func updateTable()
    {
        tableView.reloadData()
    }

    func selectionChanged(_ selectedItems: FilesAndKeywords)
    {
        filesAndKeywords = selectedItems
        tableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int
    {
        let keywordCount = filesAndKeywords.uniqueKeywords.count;
        return keywordCount / tableView.numberOfColumns + ((keywordCount % tableView.numberOfColumns) == 0 ? 0 : 1)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
    {
        if filesAndKeywords.uniqueKeywords.count == 0 {
            return nil
        }
        var columnView:NSButton? = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "keywordView"), owner: tableView) as! NSButton?
        if (columnView == nil)
        {
            let control = NSButton(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
            control.identifier = NSUserInterfaceItemIdentifier(rawValue: "keywordView")
            
            control.setButtonType(NSButton.ButtonType.onOff)
            control.bezelStyle = NSButton.BezelStyle.rounded
            control.action = #selector(PeachWindowController.mediaItemKeywordClick(_:))
            
            columnView = control
        }
        
        let columnIndex = getColumnIndex(tableView, tableColumn: tableColumn!)
        let keywordIndex = (row * tableView.numberOfColumns) + columnIndex
        columnView?.tag = keywordIndex
        if keywordIndex >= filesAndKeywords.uniqueKeywords.count {
            columnView?.isTransparent = true
        } else {
            let keyword = filesAndKeywords.uniqueKeywords[keywordIndex]
            columnView?.title = keyword
            columnView?.isTransparent = false
            columnView?.state = filesAndKeywords.uniqueKeywords.contains(keyword) ? .on : .off
        }
        
        return columnView
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any?
    {
        if filesAndKeywords.uniqueKeywords.count == 0 {
            return nil
        }

        return tableColumn?.dataCell
        
//        let columnIndex = getColumnIndex(tableView, tableColumn: tableColumn!)
//        let cell = tableColumn?.dataCell as! NSButtonCell
//        let keywordIndex = (row * tableView.numberOfColumns) + columnIndex
//
//        if keywordIndex >= filesAndKeywords.uniqueKeywords.count {
//            cell.isTransparent = true
//        } else {
//            let keyword = filesAndKeywords.uniqueKeywords[keywordIndex]
//            cell.title = keyword
//            cell.isTransparent = false
//        }
//
//        return cell
    }

    func getColumnIndex(_ tableView: NSTableView, tableColumn: NSTableColumn) -> Int
    {
        for index in 0 ..< tableView.numberOfColumns {
            if tableView.tableColumns[index] == tableColumn {
                return index
            }
        }
        
        return -1
    }
}
