//
//  PeachMetadata
//

import RangicCore

class Preferences : BasePreferences
{
    static fileprivate let BaseLocationLookupKey = "BaseLocationLookup"
    static fileprivate let ThumbnailZoomKey = "ThumbnailZoom"
    static fileprivate let PlacenameLevelKey = "PlacenameLevel"
    static fileprivate let LastOpenedFolderKey = "LastOpenedFolder"
    static fileprivate let LastSelectedFolderKey = "LastSelectedFolder"
    static fileprivate let LastImportedFolderKey = "LastImportedFolder"


    enum PlacenameLevel: Int
    {
        case short = 1, medium = 2, long = 3
    }


    static func setMissingDefaults()
    {
        setDefaultValue("http://jupiter/reversenamelookup", key: BaseLocationLookupKey)
        setDefaultValue(PlacenameLevel.medium.rawValue, key: PlacenameLevelKey)
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
        case .short:
            return .standard
        case .medium:
            return .detailed
        case .long:
            return .minimal
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
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].path.stringByAppendingPath("Preferences")
    }
}
