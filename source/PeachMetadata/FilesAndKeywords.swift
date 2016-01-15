//
//  FilesAndKeywords.swift
//

import RangicCore

public class FilesAndKeywords
{
    private let mediaItems: [MediaData]
    public private(set) var uniqueKeywords: [String]
    private let originalKeywords: [String]
    private var addedKeywords = Set<String>()
    private var removedKeywords = Set<String>()


    public init()
    {
        mediaItems = [MediaData]()
        uniqueKeywords = [String]()
        originalKeywords = uniqueKeywords
    }

    public init(mediaItems: [MediaData])
    {
        self.mediaItems = mediaItems

        var unique = Set<String>()
        for m in mediaItems {
            if let mediaKeywords = m.keywords {
                for k in mediaKeywords {
                    unique.insert(k)
                }
            }
        }

        uniqueKeywords = unique.map({$0}).sort()
        originalKeywords = uniqueKeywords
    }

    public func addKeyword(keyword: String)
    {
        if !uniqueKeywords.contains(keyword) {
            addedKeywords.insert(keyword)
            removedKeywords.remove(keyword)
            uniqueKeywords.append(keyword)
            uniqueKeywords = uniqueKeywords.sort()
        }
    }

    public func removeKeyword(keyword: String)
    {
        if let index = uniqueKeywords.indexOf(keyword) {
            addedKeywords.remove(keyword)
            removedKeywords.insert(keyword)
            uniqueKeywords.removeAtIndex(index)
        }
    }

    public func save() throws -> Bool
    {
        var filePaths = [String]()
        for m in mediaItems {
            filePaths.append(m.url!.path!)
        }

        let ret = try ExifToolRunner.updateKeywords(filePaths, addedKeywords: addedKeywords.map({$0}), removedKeywords: removedKeywords.map({$0}))

        addedKeywords.removeAll()
        removedKeywords.removeAll()

        if ret {
            for m in mediaItems {
                m.reload()
            }
        }

        return ret
    }
}