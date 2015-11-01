//
//  PeachMetadata
//

import AppKit
import RangicCore

class AllKeywordsTableViewController : NSObject, NSTableViewDelegate, NSTableViewDataSource
{
    func numberOfRowsInTableView(tableView: NSTableView) -> Int
    {
        let keywordCount = AllKeywords.sharedInstance.keywords.count;
        return keywordCount / tableView.numberOfColumns + ((keywordCount % tableView.numberOfColumns) == 0 ? 0 : 1)
    }

    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject?
    {
        let keywords = AllKeywords.sharedInstance.keywords
        if keywords.count == 0 {
            return nil
        }

        let columnIndex = getColumnIndex(tableView, tableColumn: tableColumn!)
        let cell = tableColumn?.dataCell as! NSButtonCell
        let keywordIndex = (row * tableView.numberOfColumns) + columnIndex

        if keywordIndex >= keywords.count {
            cell.transparent = true
        } else {
            cell.title = keywords[keywordIndex]
            cell.transparent = false
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
