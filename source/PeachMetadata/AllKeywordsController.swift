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

    func keywordToggled()
    {
        let index = tableView.tableColumns.count * tableView.clickedRow + tableView.clickedColumn
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

    func selectionChanged(selectedItems: FilesAndKeywords)
    {
        filesAndKeywords = selectedItems
        tableView.reloadData()
    }

    func numberOfRowsInTableView(tableView: NSTableView) -> Int
    {
        let keywordCount = AllKeywords.sharedInstance.keywords.count;
        return keywordCount / tableView.numberOfColumns + ((keywordCount % tableView.numberOfColumns) == 0 ? 0 : 1)
    }

    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject?
    {
        if AllKeywords.sharedInstance.keywords.count == 0 {
            return nil
        }

        let columnIndex = getColumnIndex(tableView, tableColumn: tableColumn!)
        let cell = tableColumn?.dataCell as! NSButtonCell
        let keywordIndex = (row * tableView.numberOfColumns) + columnIndex

        if keywordIndex >= AllKeywords.sharedInstance.keywords.count {
            cell.transparent = true
        } else {
            let keyword = AllKeywords.sharedInstance.keywords[keywordIndex]
            cell.title = keyword
            cell.transparent = false
            cell.state = filesAndKeywords.uniqueKeywords.contains(keyword) ? NSOnState : NSOffState
        }

        return cell
    }

    func getColumnIndex(tableView: NSTableView, tableColumn: NSTableColumn) -> Int
    {
        for index in 0 ..< tableView.numberOfColumns {
            if tableView.tableColumns[index] == tableColumn {
                return index
            }
        }

        return -1
    }

/// OR try: http://stackoverflow.com/questions/18858208/autoresize-nstableviews-columns-to-fit-content ?
//      that may use a deprecated api
//    func getMaxCellWidth(tableView: NSTableView) -> Float
//    {
//        var maxWidth: Float = 0
//        for column in 0..<tableView.numberOfColumns {
//            for row in 0..<tableView.numberOfRows {
//                let columnView = tableView.viewAtColumn(column, row: row, makeIfNecessary: true)
//                Logger.info("columnView for \(row),\(column) is \(columnView)")
//                let cellWidth = tableView.cell
//            }
//        }
//        return maxWidth
//    }
}
