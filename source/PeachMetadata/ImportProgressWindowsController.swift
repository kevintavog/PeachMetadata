//
//
//

import AppKit

import Async
import RangicCore


class ImportProgressWindowsController : NSWindowController, ImportProgress
{
    @IBOutlet weak var overviewLabel: NSTextField!
    @IBOutlet weak var overviewDestination: NSTextField!
    @IBOutlet weak var stepLabel: NSTextField!
    @IBOutlet var detailTextView: NSTextView!
    @IBOutlet weak var cancelCloseButton: NSButton!

    var importFolder = String()
    var destinationFolder = String()
    var originalMediaData = [MediaData]()
    var exportedMediaData = [MediaData]()
    var isRunningImport = false


    func start(_ importFolder: String, destinationFolder: String, originalMediaData: [MediaData], exportedMediaData: [MediaData])
    {
        self.importFolder = importFolder
        self.destinationFolder = destinationFolder
        self.originalMediaData = originalMediaData
        self.exportedMediaData = exportedMediaData

        overviewLabel.stringValue = "Importing from \(importFolder)"
        overviewDestination.stringValue = "to \(destinationFolder)"
        stepLabel.stringValue = ""
        detailTextView.string = ""
        isRunningImport = true

        Async.background {
            self.doImport()
            self.isRunningImport = false

            Async.main {
                self.addDetailText("\n\nDone with import", addNewLine: true)
                self.cancelCloseButton.title = "Close"
            }
        }

        NSApplication.shared.runModal(for: window!)
    }

    @IBAction func onCancel(_ sender: AnyObject)
    {
        if isRunningImport {
            Logger.warn("Import canceled")
        }
        close()
        NSApplication.shared.stopModal(withCode: NSApplication.ModalResponse(rawValue: isRunningImport ? 0 : 1))
    }

    func doImport()
    {
        do {
            let importer = ImportLightroomExport(originalMediaData: originalMediaData, exportedMediaData: exportedMediaData)
            try importer.run(self, importFolder: importFolder, destinationFolder: destinationFolder)
        } catch let error {
            Logger.error("Failed importing: \(error)")
        }
    }

    func setCurrentStep(_ stepName: String)
    {
        Logger.info("Import step: \(stepName)")

        Async.main {
            self.stepLabel.stringValue = "\(stepName)"
        }
        addDetailText("\(stepName):", addNewLine: self.detailTextView.string.count > 0)
    }

    func setStepDetail(_ detail: String)
    {
        Logger.info(" --> \(detail)")
        addDetailText("\(detail)", addNewLine: true)
    }

    func addDetailText(_ text: String, addNewLine: Bool)
    {
        Async.main {
            if addNewLine {
                self.detailTextView.string += "\n\(text)"
            } else {
                self.detailTextView.string += "\(text)"
            }

            self.detailTextView.scrollToEndOfDocument(self)
        }
    }
}
