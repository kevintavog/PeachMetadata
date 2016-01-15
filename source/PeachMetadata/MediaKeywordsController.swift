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

    func keywordToggled()
    {
        let index = tableView.tableColumns.count * tableView.clickedRow + tableView.clickedColumn
        let keyword = filesAndKeywords.uniqueKeywords[index]
        filesAndKeywords.removeKeyword(keyword)
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
        let keywordCount = filesAndKeywords.uniqueKeywords.count;
        return keywordCount / tableView.numberOfColumns + ((keywordCount % tableView.numberOfColumns) == 0 ? 0 : 1)
    }

    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject?
    {
        if filesAndKeywords.uniqueKeywords.count == 0 {
            return nil
        }

        let columnIndex = getColumnIndex(tableView, tableColumn: tableColumn!)
        let cell = tableColumn?.dataCell as! NSButtonCell
        let keywordIndex = (row * tableView.numberOfColumns) + columnIndex

        if keywordIndex >= filesAndKeywords.uniqueKeywords.count {
            cell.transparent = true
        } else {
            let keyword = filesAndKeywords.uniqueKeywords[keywordIndex]
            cell.title = keyword
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