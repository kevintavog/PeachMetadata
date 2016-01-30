//
//  ImportLightroomExport.swift
//

import RangicCore


public enum ImportError : ErrorType {
    case DestinationIsAFile(path: String)
    case FilenameExistsInDestination(filename: String)
}

protocol ImportProgress
{
    func setCurrentStep(stepName: String)
    func setStepDetail(detail: String)
}

class ImportLightroomExport
{
    private var importProgress: ImportProgress?
    private var destinationFolder: String?
    private var originalMediaData: [MediaData]
    private var exportedMediaData: [MediaData]

    init(originalMediaData: [MediaData], exportedMediaData: [MediaData])
    {
        self.originalMediaData = originalMediaData
        self.exportedMediaData = exportedMediaData
    }


    func run(progress: ImportProgress, importFolder: String, destinationFolder: String) throws
    {
        self.importProgress = progress
        self.destinationFolder = destinationFolder


        // Setup - Generate data to make checks quicker
        try setup()

        // STEP: Move exported files
        try moveExported()

        // STEP: Move all original files to destination folder
        try moveOriginals()

        // STEP: Convert videos
        try convertVideos()

        // STEP: Archive originals
        try archiveOriginals()

        // STEP: Remove Original & Exported folders
        try removeImportFolders(importFolder)
    }

    func findWarnings() -> [String]
    {
        var result = [String]()

        var originalNames = [String:MediaData]()
        for o in originalMediaData {
            originalNames[o.url!.URLByDeletingPathExtension!.lastPathComponent!] = o
        }
        var exportedNames = [String:MediaData]()
        for e in exportedMediaData {
            exportedNames[e.url!.URLByDeletingPathExtension!.lastPathComponent!] = e
        }


        // Lightroom does a horrible job with the exported video metadata - the metadata dates are export time rather than
        // original time and the location information is in an unknown (possibly non-standard) location. On top of that,
        // the video is re-encoded as part of the export process.
        // For these reasons, videos in 'Exported' trigger a warning and are ignored for the import


        // Each non-video file in originals needs to have a matching file in exported
        for oname in originalNames {
            if oname.1.type! != .Video && !exportedNames.keys.contains(oname.0) {
                result.append("Original file \(oname.1.name!) not in exported list")
            }

            // Annoyingly, the Canon T3i uses camera time when setting the UTC timestamp in videos - it should use UTC, but doesn't have a timezone setting
            if oname.1.type! == .Video && oname.1.compatibleBrands.contains("CAEP") {
                result.append("Original file \(oname.1.name!) is a Canon movie - the timestamp will need to be adjusted to UTC")
            }
        }

        // Each exported file should have a matching file in originals
        for ename in exportedNames {
            if !originalNames.keys.contains(ename.0) {
                result.append("Exported file \(ename.1.name) has no matching file in original list")
            }
        }

        // Each exported needs to have a proper date/time & a location
        for e in exportedMediaData {
            if !e.doFileAndExifTimestampsMatch() {
                result.append("Exported file \(e.name) has mismatched timestamps")
            }
            if e.location == nil {
                result.append("Exported file \(e.name) is missing location")
            } else {
                if SensitiveLocations.sharedInstance.isSensitive(e.location) {
                    result.append("Exported file \(e.name) is in a sensitive location")
                }
            }
        }

        // Exported files should not contain videos
        for e in exportedMediaData {
            if e.type == .Video {
                result.append("Videos in Exported are ignored: \(e.name)")
            }
        }

        return result
    }

    //-------------------------------------------------------------------------------------------------------------
    // Step functions
    //-------------------------------------------------------------------------------------------------------------
    func setup() throws
    {
        Logger.info("Importing to \(destinationFolder!)")
        importProgress?.setCurrentStep("Setting up")

        var existingFilenames = [String]()
        var isFolder: ObjCBool = false
        if NSFileManager.defaultManager().fileExistsAtPath(destinationFolder!, isDirectory:&isFolder) {
            if !isFolder {
                throw ImportError.DestinationIsAFile(path: destinationFolder!)
            }

            let urls = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(
                    NSURL(fileURLWithPath: destinationFolder!),
                    includingPropertiesForKeys: nil,
                    options:NSDirectoryEnumerationOptions.SkipsHiddenFiles)
            for u in urls {
                existingFilenames.append(u.lastPathComponent!)
            }
        } else {
            try NSFileManager.defaultManager().createDirectoryAtPath(destinationFolder!, withIntermediateDirectories: true, attributes: nil)
        }

        // Generate filenames that will be used - so we can find duplicates
        var generatedNames = Set<String>()
        var generatedUrlToName = [NSURL:String]()
        for md in originalMediaData {
            let name = generateDestinationName(md.name, isOriginal: true)
            generatedNames.insert(name)
            generatedUrlToName[md.url!] = name
        }
        for md in exportedMediaData {
            let name = generateDestinationName(md.name, isOriginal: false)
            generatedNames.insert(name)
            generatedUrlToName[md.url!] = name
        }

        // Do any generated/destination names conflict with existing filenames?
        for existing in existingFilenames {
            if generatedNames.contains(existing) {
                throw ImportError.FilenameExistsInDestination(filename: existing)
            }
        }
    }

    func moveExported() throws
    {
        importProgress?.setCurrentStep("Moving files from exported folder")

        // Move all exportedMediaData files to destination folder before original in case of accidental overwrites
        for media in exportedMediaData {
            if media.type == .Image {
                let destinationFile = "\(destinationFolder!)/\(media.name!)"
                importProgress?.setStepDetail("Moving from \(media.url!.path!) to \(destinationFile)")

                do {
                    try NSFileManager.defaultManager().moveItemAtPath(media.url!.path!, toPath: destinationFile)
                } catch let error {
                    Logger.error("Failed moving \(media.url!.path!): \(error)")
                    importProgress?.setStepDetail("Failed moving \(media.url!.path!): \(error)")
                }

            } else {
                importProgress?.setStepDetail("Skipping unsupported file in 'Exported': \(media.name!)")
            }
        }
    }

    func moveOriginals() throws
    {
        importProgress?.setCurrentStep("Moving files from originals folder")

        // Rename *.JPG to *-org.JPG
        for media in originalMediaData {
            let destinationFile = "\(destinationFolder!)/\(generateDestinationName(media.name, isOriginal: true))"
            importProgress?.setStepDetail("Moving from \(media.url!.path!) to \(destinationFile)")

            do {
                try NSFileManager.defaultManager().moveItemAtPath(media.url!.path!, toPath: destinationFile)
            } catch let error {
                Logger.error("Failed moving \(media.url!.path!): \(error)")
                importProgress?.setStepDetail("Failed moving \(media.url!.path!): \(error)")
            }
        }
    }

    func convertVideos() throws
    {
        // Convert items that are videos that haven't already been converted
        let videos = originalMediaData.filter( { $0.type == .Video && !$0.name.hasSuffix("_V.MP4") } )
        if videos.count < 1 {
            return
        }

        importProgress?.setCurrentStep("Converting videos")
        for m in videos {
            importProgress?.setStepDetail(m.name)
            let rotationOption = getRotationOption(m)

            // The video has been moved - refer to the new location
            let sourceName = "\(destinationFolder!)/\(m.name)"
            convertVideo(sourceName, destinationName: "\(destinationFolder!)/\(m.nameWithoutExtension)_V.MP4", rotationOption: rotationOption)
        }
    }

    func archiveOriginals() throws
    {
        // The script is failing because it can't find 'ping'
//        importProgress?.setCurrentStep("Archiving originals")

//        let result = ProcessInvoker.run("/bin/bash", arguments: ["/Users/goatboy/Tools/archiveOriginals.sh"])
//        addProcessResultDetail("archiveOriginals", processResult: result)
    }

    func removeImportFolders(importFolder: String) throws
    {
        importProgress?.setCurrentStep("Removing original/import folder: \(importFolder)")

        let enumerator = NSFileManager.defaultManager().enumeratorAtURL(
            NSURL(fileURLWithPath: importFolder, isDirectory: true),
            includingPropertiesForKeys: [NSURLIsDirectoryKey],
            options: .SkipsHiddenFiles,
            errorHandler: { (url: NSURL, error: NSError) -> Bool in return true })

        var hadError = false
        var fileCount = 0
        if enumerator != nil {
            for e in enumerator!.allObjects {
                let url = e as! NSURL

                do {
                    var resource: AnyObject?
                    try url.getResourceValue(&resource, forKey: NSURLIsDirectoryKey)
                    if let isDirectory = resource as? Bool {
                        if !isDirectory {
                            ++fileCount
                        }
                    }
                } catch let error {
                    hadError = true
                    Logger.error("Failed finding remaining files in original/import folder: \(error)")
                }
            }
        }

        if fileCount == 0 && hadError == false {
            try NSFileManager.defaultManager().removeItemAtPath(importFolder)
        } else {
            Logger.error("Not removing original folder due to existing files")
            importProgress?.setStepDetail("Not removing original folder due to existing files")
        }
    }

    //-------------------------------------------------------------------------------------------------------------
    // Utility functions
    //-------------------------------------------------------------------------------------------------------------
    func getRotationOption(mediaData: MediaData) -> String
    {
        if let rotation = mediaData.rotation {
            switch rotation {
            case 90:
                return "--rotate=4"
            case 180:
                return "--rotate=3"
            case 270:
                return "--rotate=7"
            case 0:
                return ""
            default:
                Logger.warn("Unhandled rotation \(mediaData.rotation!)")
                return ""
            }
        }
        return ""
    }

    func convertVideo(sourceName: String, destinationName: String, rotationOption: String)
    {
        // Use the HandBrake command line - it uses ffmpeg and  is both easier to install and has a more stable CLI than ffmpeg
        let handbrakePath = "/Applications/Extras/HandBrakeCLI"
        let handbrakeResult = ProcessInvoker.run(handbrakePath,
            arguments: [ "-e", "x264", "-q", "20.0", "-a", "1", "-E", "faac", "-B", "160", "-6", "dpl2", "-R", "Auto", "-D",
                "0.0", "--audio-copy-mask", "aac,ac3,dtshd,dts,mp3", "--audio-fallback", "ffac3", "-f", "mp4",
                "--loose-anamorphic", "--modulus", "2", "-m", "--x264-preset", "veryfast", "--h264-profile",
                "auto", "--h264-level", "auto", "-O",
                rotationOption,
                "-i", sourceName,
                "-o", destinationName])
        addProcessResultDetail("Handbrake", processResult: handbrakeResult)

        // Copy the original video metadata to the new video
        let exiftoolResult = ProcessInvoker.run(ExifToolRunner.exifToolPath,
            arguments: ["-overwrite_original", "-tagsFromFile", sourceName, destinationName])
        addProcessResultDetail("ExifTool", processResult: exiftoolResult)

        // Update the file timestamp on the new video to match the metadata timestamp
        let mediaData = FileMediaData.create(NSURL(fileURLWithPath: destinationName), mediaType: .Video)
        mediaData.setFileDateToExifDate()
    }

    func addProcessResultDetail(name: String, processResult: ProcessInvoker)
    {
        importProgress?.setStepDetail("\(name) exit code: \(processResult.exitCode)")
        if processResult.exitCode != 0 {
            importProgress?.setStepDetail("\(name) standard output: \(processResult.output)")
            importProgress?.setStepDetail("\(name) error output: \(processResult.error)")
        }
    }

    func generateDestinationName(name: NSString, isOriginal: Bool) -> String
    {
        var newName = name
        if isOriginal && name.pathExtension.compare("JPG", options: NSStringCompareOptions.CaseInsensitiveSearch, range: nil, locale: nil) == .OrderedSame {
            newName = name.stringByDeletingPathExtension + "-org.JPG"
        }
        return newName as String
    }
}
