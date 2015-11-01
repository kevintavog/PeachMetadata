//
//  PeachMetadata
//

import AppKit
import RangicCore

class MediaKeywordsTableController : NSObject, NSTableViewDelegate, NSTableViewDataSource
{
    let tableView: NSTableView
    var selectedKeywords = [String]()


    init(tableView: NSTableView)
    {
        self.tableView = tableView
    }

    func selectionChanged(keywords: [String])
    {
        selectedKeywords = keywords.sort()
        tableView.reloadData()
    }

    func numberOfRowsInTableView(tableView: NSTableView) -> Int
    {
        let keywordCount = selectedKeywords.count;
        return keywordCount / tableView.numberOfColumns + ((keywordCount % tableView.numberOfColumns) == 0 ? 0 : 1)
    }

    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject?
    {
        let keywords = selectedKeywords
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
}