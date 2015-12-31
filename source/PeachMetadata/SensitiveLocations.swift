//
//  SensitiveLocations.swift
//

import RangicCore

class SensitiveLocations
{
    private let SensitiveDistanceInMeters: Double = 50


    static var sharedInstance: SensitiveLocations
    {
        struct _Singleton {
            static let instance = SensitiveLocations()
        }
        return _Singleton.instance
    }

    private var locations = [Location]()


    func isSensitive(location: Location) -> Bool
    {
        for loc in locations {
            return loc.metersFrom(location) < SensitiveDistanceInMeters
        }
        return false
    }


    func add(location: Location)
    {
        for loc in locations {
            if loc.metersFrom(location) <= SensitiveDistanceInMeters {
                return
            }
        }

        locations.append(location)
        save()
    }

    private func save()
    {
        var asDictionary = [Dictionary<String, AnyObject>]()
        for loc in locations {
            asDictionary.append(locationToDictionary(loc))
        }

        do {
            let json = JSON(asDictionary)
            let jsonString: String = json.rawString()!
            try jsonString.writeToFile(fullLocationFilename, atomically: false, encoding: NSUTF8StringEncoding)
        } catch let error {
            Logger.error("Unable to save locations: \(error)")
        }
    }

    private func locationToDictionary(location: Location) -> Dictionary<String, AnyObject>
    {
        return [
            "latitude" : location.latitude,
            "longitude" : location.longitude]
    }

    private var fullLocationFilename: String { return Preferences.preferencesFolder.stringByAppendingPath("rangic.PeachMetadata.sensitive.locations") }


    private init()
    {
        if let data = NSData(contentsOfFile: fullLocationFilename) {
            let json = JSON(data:NSData(data: data))

            var rawLocationList = [Location]()
            for (_,subjson):(String,JSON) in json {
                let latitude = subjson["latitude"].doubleValue
                let longitude = subjson["longitude"].doubleValue

                rawLocationList.append(Location(latitude: latitude, longitude: longitude))
            }

            updateLocations(rawLocationList)
        } else {
            // Save an empty file to the proper location - it can be edited by hand, if needed
            save()
        }
    }

    private func updateLocations(rawList: [Location])
    {
        locations = rawList
    }
}
