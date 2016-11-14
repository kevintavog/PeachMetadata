//
//  SensitiveLocations.swift
//

import RangicCore
import SwiftyJSON

class SensitiveLocations
{
    let SensitiveDistanceInMeters: Double = 50


    static var sharedInstance: SensitiveLocations
    {
        struct _Singleton {
            static let instance = SensitiveLocations()
        }
        return _Singleton.instance
    }

    fileprivate(set) var locations = [Location]()


    func isSensitive(_ location: Location) -> Bool
    {
        for loc in locations {
            if loc.metersFrom(location) < SensitiveDistanceInMeters {
                return true
            }
        }
        return false
    }

    func add(_ location: Location)
    {
        for loc in locations {
            if loc.metersFrom(location) <= SensitiveDistanceInMeters {
                return
            }
        }

        locations.append(location)
        save()
    }

    func remove(_ location: Location)
    {
        for loc in locations {
            if loc.metersFrom(location) <= SensitiveDistanceInMeters {
                locations.remove(at: locations.index(where: { $0 === loc })!)
                save()
                return
            }
        }
    }
    
    fileprivate func save()
    {
        var asDictionary = [Dictionary<String, AnyObject>]()
        for loc in locations {
            asDictionary.append(locationToDictionary(loc))
        }

        do {
            let json = JSON(asDictionary)
            let jsonString: String = json.rawString()!
            try jsonString.write(toFile: fullLocationFilename, atomically: false, encoding: String.Encoding.utf8)
        } catch let error {
            Logger.error("Unable to save locations: \(error)")
        }
    }

    fileprivate func locationToDictionary(_ location: Location) -> Dictionary<String, AnyObject>
    {
        return [
            "latitude" : location.latitude as AnyObject,
            "longitude" : location.longitude as AnyObject]
    }

    fileprivate var fullLocationFilename: String { return Preferences.preferencesFolder.stringByAppendingPath("rangic.PeachMetadata.sensitive.locations") }


    fileprivate init()
    {
        if let data = NSData(contentsOfFile: fullLocationFilename) {
            let json = JSON(data:NSData(data: data as Data) as Data)

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

    fileprivate func updateLocations(_ rawList: [Location])
    {
        locations = rawList
    }
}
