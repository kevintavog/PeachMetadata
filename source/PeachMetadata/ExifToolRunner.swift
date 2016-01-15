//
//  ExifToolRunner.swift
//

import RangicCore

public enum ExifToolError : ErrorType {
    case NotAFile(path: String)
    case UpdateFailed(error: String)
}

public class ExifToolRunner
{
    static public func clearFileLocations(imageFilePaths: [String], videoFilePaths: [String]) throws
    {
        try checkFiles(imageFilePaths)
        try checkFiles(videoFilePaths)

        if imageFilePaths.count > 0 {
            try runExifTool(
                [ "-P", "-fast", "-q", "-overwrite_original",
                    "-exif:gpslatitude=",
                    "-exif:gpslatituderef=",
                    "-exif:gpslongitude=",
                    "-exif:gpslongituderef="]
                    + imageFilePaths)
        }

        if videoFilePaths.count > 0 {
            try runExifTool(
                [ "-P", "-fast", "-q", "-overwrite_original",
                    "-xmp:gpslatitude=",
                    "-xmp:gpslongitude="]
                    + videoFilePaths)
        }
    }

    static public func updateFileLocations(imageFilePaths: [String], videoFilePaths: [String], location: Location) throws
    {
        try checkFiles(imageFilePaths)
        try checkFiles(videoFilePaths)

        if imageFilePaths.count > 0 {
            let latRef = location.latitude < 0 ? "S" : "N"
            let lonRef = location.longitude < 0 ? "W" : "E"
            let absLat = abs(location.latitude)
            let absLon = abs(location.longitude)

            try runExifTool(
                [ "-P", "-fast", "-q", "-overwrite_original",
                "-exif:gpslatitude=\(absLat)",
                "-exif:gpslatituderef=\(latRef)",
                "-exif:gpslongitude=\(absLon)",
                "-exif:gpslongituderef=\(lonRef)"]
                + imageFilePaths)
        }

        if videoFilePaths.count > 0 {
            let latRef = location.latitude < 0 ? "S" : "N"
            let absLat = abs(location.latitude)
            let latDegrees = Int(absLat)
            let latMinutesAndSeconds = (absLat - Double(latDegrees)) * 60.0

            let lonRef = location.longitude < 0 ? "W" : "E"
            let absLong = abs(location.longitude)
            let lonDegrees = Int(absLong)
            let lonMinutesAndSeconds = (absLong - Double(lonDegrees)) * 60.0


            try runExifTool(
                [ "-P", "-fast", "-q", "-overwrite_original",
                    "-xmp:gpslatitude=\(latDegrees),\(latMinutesAndSeconds)\(latRef)",
                    "-xmp:gpslongitude=\(lonDegrees),\(lonMinutesAndSeconds)\(lonRef)"]
                    + videoFilePaths)
        }
    }

    static public func updateKeywords(filePaths: [String], addedKeywords: [String], removedKeywords: [String]) throws -> Bool
    {
        if addedKeywords.count == 0 && removedKeywords.count == 0 {
            return false
        }

        var keywordCommands = [String]()
        for s in addedKeywords {
            keywordCommands.append("-IPTC:Keywords+=\(s)")
            keywordCommands.append("-XMP:Subject+=\(s)")
        }
        for s in removedKeywords {
            keywordCommands.append("-IPTC:Keywords-=\(s)")
            keywordCommands.append("-XMP:Subject-=\(s)")
        }

        try runExifTool(
            [ "-P", "-overwrite_original"]
                + keywordCommands
                + filePaths)

        return true
    }

    static public func setMetadataDates(videoFilePaths: [String], newDate: NSDate) throws
    {
        // Some dates in Canon videos aren't updatable via exiftool (due to Canon silliness). Bummer
        // http://u88.n24.queensu.ca/exiftool/forum/index.php?topic=6563.0
        if videoFilePaths.count > 0 {

            let dateFormatter = NSDateFormatter()
            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            let localDateString = dateFormatter.stringFromDate(newDate)
            dateFormatter.timeZone = NSTimeZone(name: "UTC")
            let utcDateString = dateFormatter.stringFromDate(newDate)

            try runExifTool(
                ["-overwrite_original",
                     "-AllDates='\(utcDateString)'",
                     "-quicktime:TrackCreateDate='\(utcDateString)'",
                     "-quicktime:TrackCreateDate='\(utcDateString)'",
                     "-quicktime:TrackModifyDate='\(utcDateString)'",
                     "-quicktime:MediaCreateDate='\(utcDateString)'",
                     "-quicktime:MediaModifyDate='\(utcDateString)'",
                     "-ExifIFD:CreateDate='\(localDateString)'",
                     "-ExifIFD:DateTimeOriginal='\(localDateString)'",
                     "-IFD0:ModifyDate='\(localDateString)'"]
                     + videoFilePaths)
        }
    }

    static public var exifToolPath: String { return "/usr/local/bin/exiftool" }

    static private func checkFiles(filePaths: [String]) throws
    {
        for file in filePaths {
            if !NSFileManager.defaultManager().fileExistsAtPath(file) {
                throw ExifToolError.NotAFile(path: file)
            }
        }
    }

    static private func runExifTool(arguments: [String]) throws -> String
    {
        let process = ProcessInvoker.run(exifToolPath, arguments: arguments)
        if process.exitCode == 0 {
            return process.output
        }

        throw ExifToolError.UpdateFailed(error: "exiftool failed: \(process.exitCode); error: '\(process.error)'")
    }
}