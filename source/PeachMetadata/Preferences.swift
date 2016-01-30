//
//  PeachMetadata
//

import RangicCore

class Preferences : BasePreferences
{
    static private let BaseLocationLookupKey = "BaseLocationLookup"
    static private let ThumbnailZoomKey = "ThumbnailZoom"
    static private let PlacenameLevelKey = "PlacenameLevel"
    static private let LastOpenedFolderKey = "LastOpenedFolder"
    static private let LastSelectedFolderKey = "LastSelectedFolder"
    static private let LastImportedFolderKey = "LastImportedFolder"


    enum PlacenameLevel: Int
    {
        case Short = 1, Medium = 2, Long = 3
    }


    static func setMissingDefaults()
    {
        setDefaultValue("http://geo.local:2000", key: BaseLocationLookupKey)
        setDefaultValue(PlacenameLevel.Medium.rawValue, key: PlacenameLevelKey)
        setDefaultValue(Float(0.43), key: ThumbnailZoomKey)
    }

    static var baseLocationLookup: String
    {
        get { return stringForKey(BaseLocationLookupKey) }
        set { super.setValue(newValue, key: BaseLocationLookupKey) }
    }

    static var placenameLevel: PlacenameLevel
    {
        get { return PlacenameLevel(rawValue: intForKey(PlacenameLevelKey))! }
        set { super.setValue(newValue.rawValue, key: PlacenameLevelKey) }
    }

    static var placenameFilter: PlaceNameFilter
    {
        switch placenameLevel {
        case .Short:
            return .Standard
        case .Medium:
            return .Detailed
        case .Long:
            return .Minimal
        }
    }
    
    static var thumbnailZoom: Float
    {
        get { return floatForKey(ThumbnailZoomKey) }
        set { super.setValue(newValue, key: ThumbnailZoomKey) }
    }

    static var lastOpenedFolder : String
    {
        get { return stringForKey(LastOpenedFolderKey) }
        set { super.setValue(newValue, key: LastOpenedFolderKey) }
    }
    
    static var lastSelectedFolder : String
    {
        get { return stringForKey(LastSelectedFolderKey) }
        set { super.setValue(newValue, key: LastSelectedFolderKey) }
    }

    static var lastImportedFolder : String
    {
        get { return stringForKey(LastImportedFolderKey) }
        set { super.setValue(newValue, key: LastImportedFolderKey) }
    }

    static var preferencesFolder: String
    {
        return NSFileManager.defaultManager().URLsForDirectory(.LibraryDirectory, inDomains: .UserDomainMask)[0].path!.stringByAppendingPath("Preferences")
    }
}
