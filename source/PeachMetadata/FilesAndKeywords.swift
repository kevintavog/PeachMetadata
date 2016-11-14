//
//  FilesAndKeywords.swift
//

import RangicCore

open class FilesAndKeywords
{
    fileprivate let mediaItems: [MediaData]
    open fileprivate(set) var uniqueKeywords: [String]
    fileprivate let originalKeywords: [String]
    fileprivate var addedKeywords = Set<String>()
    fileprivate var removedKeywords = Set<String>()


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

        uniqueKeywords = unique.map({$0}).sorted()
        originalKeywords = uniqueKeywords
    }

    open func addKeyword(_ keyword: String)
    {
        if !uniqueKeywords.contains(keyword) {
            addedKeywords.insert(keyword)
            removedKeywords.remove(keyword)
            uniqueKeywords.append(keyword)
            uniqueKeywords = uniqueKeywords.sorted()
        }
    }

    open func removeKeyword(_ keyword: String)
    {
        if let index = uniqueKeywords.index(of: keyword) {
            addedKeywords.remove(keyword)
            removedKeywords.insert(keyword)
            uniqueKeywords.remove(at: index)
        }
    }

    open func save() throws -> Bool
    {
        var filePaths = [String]()
        for m in mediaItems {
            filePaths.append(m.url!.path)
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
