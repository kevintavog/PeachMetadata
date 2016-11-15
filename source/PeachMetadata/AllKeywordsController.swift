//
//  PeachMetadata
//

import AppKit
import RangicCore

class AllKeywordsTableViewController : NSObject, NSTableViewDelegate, NSTableViewDataSource
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
        let keyword = AllKeywords.sharedInstance.keywords[index]

        if filesAndKeywords.uniqueKeywords.contains(keyword) {
            filesAndKeywords.removeKeyword(keyword)
        } else {
            filesAndKeywords.addKeyword(keyword)
        }
    }

    func updateTable()
    {
        tableView.reloadData()
    }

    func updateColumns()
    {
        let columnWidth = self.calculateMaxColumnWidth()
        let tableWidth = tableView.bounds.width
        let columnCount = max(1, Int(tableWidth) / columnWidth)
Logger.debug("table: \(tableWidth) -- column: \(columnWidth) -- #columns: \(columnCount) -- current: \(tableView.numberOfColumns)")

        if (columnCount < tableView.numberOfColumns) {
            while (columnCount < tableView.numberOfColumns) {
                tableView.removeTableColumn(tableView.tableColumns.last!)
                Logger.debug("removed column, now \(tableView.numberOfColumns), \(tableView.tableColumns.count)")
            }
        } else if (columnCount > tableView.numberOfColumns) {
            while (columnCount > tableView.numberOfColumns) {
                tableView.addTableColumn(NSTableColumn())
                Logger.debug("added column, now \(tableView.numberOfColumns), \(tableView.tableColumns.count)")
            }
        }
    }
    
    func selectionChanged(_ selectedItems: FilesAndKeywords)
    {
//        updateColumns()
        filesAndKeywords = selectedItems
        tableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int
    {
        let keywordCount = AllKeywords.sharedInstance.keywords.count;
        return keywordCount / tableView.numberOfColumns + ((keywordCount % tableView.numberOfColumns) == 0 ? 0 : 1)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
    {
        if AllKeywords.sharedInstance.keywords.count == 0 {
            return nil
        }

        var columnView:NSButton? = tableView.make(withIdentifier: "allKeywordsView", owner: tableView) as! NSButton?
        if (columnView == nil)
        {
            let control = NSButton(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
            control.identifier = "allKeywordsView"
            
            control.setButtonType(NSButtonType.onOff)
            control.bezelStyle = NSBezelStyle.rounded
            control.action = #selector(PeachWindowController.allKeywordClick(_:))
            
            columnView = control
        }

        let columnIndex = getColumnIndex(tableView, tableColumn: tableColumn!)
        let keywordIndex = (row * tableView.numberOfColumns) + columnIndex
        columnView?.tag = keywordIndex
        if keywordIndex >= AllKeywords.sharedInstance.keywords.count {
            columnView?.isTransparent = true
        } else {
            let keyword = AllKeywords.sharedInstance.keywords[keywordIndex]
            columnView?.title = keyword
            columnView?.isTransparent = false
            columnView?.state = filesAndKeywords.uniqueKeywords.contains(keyword) ? NSOnState : NSOffState
        }

        return columnView
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
    
    func calculateMaxColumnWidth() -> Int
    {
        var maxWidth = 0
        for row in 0 ..< tableView.numberOfRows {
            for column in 0 ..< tableView.numberOfColumns {
                if let view = tableView.view(atColumn: column, row: row, makeIfNecessary: false) {
                    let width = view.fittingSize.width
                    maxWidth = max(Int(width), maxWidth)
                }
            }
        }

        return maxWidth
    }
}
