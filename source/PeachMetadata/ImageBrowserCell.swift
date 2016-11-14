//
//  PeachMetadata
//

import Quartz
import RangicCore

open class ImageBrowserCell : IKImageBrowserCell
{
    static fileprivate var lineHeight: CGFloat?
    static fileprivate let textAttrs = [NSForegroundColorAttributeName : NSColor.white, NSFontAttributeName : NSFont.labelFont(ofSize: 14)]

    static fileprivate let badDateAttrs = [
        NSForegroundColorAttributeName : NSColor.orange,
        NSFontAttributeName : NSFont.labelFont(ofSize: 14)
    ]

    static fileprivate let missingKeywordAttrs = [
        NSForegroundColorAttributeName : NSColor.cyan,
        NSFontAttributeName : NSFont.labelFont(ofSize: 14)
    ]

    static fileprivate let missingLocationAttrs = [
        NSForegroundColorAttributeName : NSColor.cyan,
        NSFontAttributeName : NSFont.labelFont(ofSize: 14)
    ]
    static fileprivate let sensitiveLocationAttrs = [
        NSForegroundColorAttributeName : NSColor.orange,
        NSFontAttributeName : NSFont.labelFont(ofSize: 14)
    ]


    // MARK: layer for type
    open override func layer(forType type: String!) -> CALayer!
    {
        switch (type!)
        {
        case IKImageBrowserCellBackgroundLayer:
            if cellState() != IKImageStateReady { return nil }

            let layer = CALayer()
            layer.frame = CGRect(x: 0, y: 0, width: frame().width, height: frame().height)

            let mediaBackgroundLayer = CALayer()
            mediaBackgroundLayer.frame = layer.frame

            let strokeComponents: [CGFloat] = [0.2, 0.2, 0.2, 0.5]
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            mediaBackgroundLayer.backgroundColor = NSColor.darkGray.cgColor

            let borderColor = CGColor(colorSpace: colorSpace, components: strokeComponents)
            mediaBackgroundLayer.borderColor = borderColor

            mediaBackgroundLayer.borderWidth = 1
            mediaBackgroundLayer.shadowOpacity = 0.1
            mediaBackgroundLayer.cornerRadius = 3

            layer.addSublayer(mediaBackgroundLayer)

            return layer;


        case IKImageBrowserCellForegroundLayer:
            if cellState() != IKImageStateReady { return nil }


            let outerLayer = CALayer()
            outerLayer.contentsScale = (self.imageBrowserView().window?.backingScaleFactor)!
            outerLayer.frame = CGRect(x: 0, y: 0, width: frame().width, height: frame().height)

            let item = representedItem() as! ThumbnailViewItem

            let nameLayer = self.createTextLayer(outerLayer: outerLayer, lineNumber: 0)
            nameLayer.string = item.mediaData.name

            let timestampLayer = self.createTextLayer(outerLayer: outerLayer, lineNumber: 1)
            if !item.mediaData.doFileAndExifTimestampsMatch() {
                timestampLayer.foregroundColor = NSColor.yellow.cgColor
            }
            timestampLayer.string = item.mediaData.formattedTime()

            let keywordsLayer = self.createTextLayer(outerLayer: outerLayer, lineNumber: 2)
            if item.mediaData.keywordsString().characters.count > 0 {
                keywordsLayer.string = item.mediaData.keywordsString()
            } else {
                keywordsLayer.string = "🏷"
            }

            let locationLayer = self.createTextLayer(outerLayer: outerLayer, lineNumber: 3)
            if let location = item.mediaData.location {
                if SensitiveLocations.sharedInstance.isSensitive(location) {
                    locationLayer.string = location.toDecimalDegrees(true)
                    locationLayer.foregroundColor = NSColor.orange.cgColor
                } else {
                    locationLayer.string = location.toDecimalDegrees(true)
                }
            } else {
                locationLayer.string = "⚑"
            }
            

            outerLayer.setNeedsDisplay()
            return outerLayer;


        case IKImageBrowserCellSelectionLayer:
            let layer = CALayer()
            layer.frame = CGRect(x: 0, y: 0, width: frame().width, height: frame().height)

            let fillComponents: [CGFloat] = [0.9, 0.9, 0.9, 0.3]
            let strokeComponents: [CGFloat] = [0.9, 0.9, 0.9, 0.8]

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var color = CGColor(colorSpace: colorSpace, components: fillComponents)
            layer.backgroundColor = color

            color = CGColor(colorSpace: colorSpace, components: strokeComponents)
            layer.borderColor = color

            layer.borderWidth = 1.0
            layer.cornerRadius = 5

            return layer;


        default:
            return super.layer(forType: type)
        }
    }

    func createTextLayer(outerLayer: CALayer, lineNumber: Int) -> CATextLayer
    {
        let lineHeight = Int(0.5 + ImageBrowserCell.getLineHeight())
        let xOffset = 4
        let lineOffset = 2

        let layer = CATextLayer()
        outerLayer.addSublayer(layer)
        layer.contentsScale = (self.imageBrowserView().window?.backingScaleFactor)!
        layer.frame = CGRect(x: xOffset, y: lineOffset + lineNumber * lineHeight, width: Int(frame().width) - 2 * xOffset, height: lineHeight)
        layer.fontSize = 14

        return layer
    }

    // MARK: Frame sizes
    open override func imageFrame() -> NSRect
    {
        let superImageFrame = super.imageFrame()
        if superImageFrame.size.height == 0 || superImageFrame.size.width == 0 { return NSZeroRect }

        let aspectRatio = superImageFrame.size.width / superImageFrame.size.height

        let containerFrame = NSInsetRect(imageContainerFrame(), 8, 8);
        if containerFrame.size.height <= 0 { return NSZeroRect }

        let containerAspectRatio = containerFrame.size.width / containerFrame.size.height

        var x, y, width, height: CGFloat
        if(containerAspectRatio > aspectRatio) {
            height = containerFrame.size.height
            y = containerFrame.origin.y
            width = superImageFrame.size.height * aspectRatio
            x = containerFrame.origin.x + (containerFrame.size.width - superImageFrame.size.width) * 0.5
        }
        else {
            width = containerFrame.size.width
            x = containerFrame.origin.x
            height = superImageFrame.size.width / aspectRatio
            y = containerFrame.origin.y + containerFrame.size.height - superImageFrame.size.height
        }

        x = floor(x)
        y = floor(y)
        width = ceil(width)
        height = ceil(height)

        let minHeight = ImageBrowserCell.getLineHeight() - 5

        var imageRect = NSRect(x: x, y: y, width: width, height: height)
        if imageRect.height >= (containerFrame.height - minHeight) {
            let heightAdjustment = imageRect.height - (containerFrame.height - minHeight)
            imageRect = NSInsetRect(imageRect, heightAdjustment, heightAdjustment)
            imageRect = NSOffsetRect(imageRect, 0, heightAdjustment)
        }

        return imageRect
    }

    open override func imageContainerFrame() -> NSRect
    {
        let portraitAdjustment: CGFloat = 9
        let videoAdjustment: CGFloat = 9

        let extraForText = 2 + ImageBrowserCell.getLineHeight() * 2
        let superRect = super.frame()
        var imageFrame = NSRect(x: superRect.origin.x, y: superRect.origin.y + extraForText, width: superRect.width, height: superRect.height - extraForText)

        let mediaData = (representedItem() as? ThumbnailViewItem)?.mediaData
        if let mediaSize = mediaData?.mediaSize {
            if mediaSize.height > mediaSize.width {
                imageFrame = NSRect(x: imageFrame.origin.x, y: imageFrame.origin.y + portraitAdjustment, width: imageFrame.width, height: imageFrame.height - portraitAdjustment)
            }
        }

        if mediaData?.type == SupportedMediaTypes.MediaType.video {
            imageFrame = NSRect(x: imageFrame.origin.x, y: imageFrame.origin.y + videoAdjustment, width: imageFrame.width, height: imageFrame.height - videoAdjustment)
        }

        return imageFrame
    }

    open override func titleFrame() -> NSRect
    {
        let titleRect = super.titleFrame()
        let containerRect = frame()

        var rect = NSRect(x: titleRect.origin.x, y: containerRect.origin.y + 3, width: titleRect.width, height: titleRect.height)

        let margin = titleRect.origin.x - (containerRect.origin.x + 7)
        if margin < 0 {
            rect = NSInsetRect(rect, -margin, 0)
        }

        return rect
    }

    open override func selectionFrame() -> NSRect
    {
        return NSInsetRect(super.frame(), -3, -3)
    }
    
    // MARK: line height helper
    static fileprivate func getLineHeight() -> CGFloat
    {
        if lineHeight == nil {
            let attrStr = NSMutableAttributedString(string: "Mj", attributes: textAttrs)
            lineHeight = CTLineGetBoundsWithOptions(CTLineCreateWithAttributedString(attrStr), CTLineBoundsOptions.useHangingPunctuation).height
        }
        return lineHeight!
    }
}
