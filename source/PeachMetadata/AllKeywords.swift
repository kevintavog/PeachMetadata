//
//  PeachMetadata
//

import Foundation
import RangicCore
import SwiftyJSON

class AllKeywords
{
    static var sharedInstance: AllKeywords
    {
        struct _Singleton {
            static let instance = AllKeywords()
        }
        return _Singleton.instance
    }

    fileprivate(set) var keywords = [String]()


    fileprivate var fullKeywordFilename: String { return Preferences.preferencesFolder.stringByAppendingPath("rangic.PeachMetadata.keywords") }


    fileprivate init()
    {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: fullKeywordFilename)) {
            if let json = try? JSON(data:data) {
                var rawKeywordList = [String]()
                for (_,subjson):(String,JSON) in json {
                    rawKeywordList.append(subjson.string!)
                }

                updateKeywords(rawKeywordList)
            }
        }
    }

    fileprivate func updateKeywords(_ rawList: [String])
    {
        keywords = rawList.sorted()
    }
}
