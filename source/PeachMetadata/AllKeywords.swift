//
//  PeachMetadata
//

import Foundation
import RangicCore

class AllKeywords
{
    static var sharedInstance: AllKeywords
    {
        struct _Singleton {
            static let instance = AllKeywords()
        }
        return _Singleton.instance
    }

    private(set) var keywords = [String]()


    private var fullKeywordFilename: String { return Preferences.preferencesFolder.stringByAppendingPath("rangic.PeachMetadata.keywords") }


    private init()
    {
        if let data = NSData(contentsOfFile: fullKeywordFilename) {
            let json = JSON(data:NSData(data: data))

            var rawKeywordList = [String]()
            for (_,subjson):(String,JSON) in json {
                rawKeywordList.append(subjson.string!)
            }

            updateKeywords(rawKeywordList)
        }
    }

    private func updateKeywords(rawList: [String])
    {
        keywords = rawList.sort()
    }

}