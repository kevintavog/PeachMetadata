//
//  PeachMetadata
//

import Quartz
import RangicCore

public class ImageBrowserCell : IKImageBrowserCell
{
    static private var lineHeight: CGFloat?
    static private let textAttrs = [NSForegroundColorAttributeName : NSColor.whiteColor(), NSFontAttributeName : NSFont.labelFontOfSize(14)]
    static private let badDateAttrs = [
        NSForegroundColorAttributeName : NSColor.yellowColor(),
        NSFontAttributeName : NSFont.labelFontOfSize(14),
        NSUnderlineStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue
    ]


    // MARK: layer for type
    public override func layerForType(type: String!) -> CALayer!
    {
        switch (type)
        {
        case IKImageBrowserCellBackgroundLayer:
            if cellState() != IKImageStateReady { return nil }

            let layer = CALayer()
            layer.frame = CGRectMake(0, 0, frame().width, frame().height)

            let photoBackgroundLayer = CALayer()
            photoBackgroundLayer.frame = layer.frame

            let strokeComponents: [CGFloat] = [0.2, 0.2, 0.2, 0.5]
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            photoBackgroundLayer.backgroundColor = NSColor.darkGrayColor().CGColor

            let borderColor = CGColorCreate(colorSpace, strokeComponents)
            photoBackgroundLayer.borderColor = borderColor

            photoBackgroundLayer.borderWidth = 1
            photoBackgroundLayer.shadowOpacity = 0.1
            photoBackgroundLayer.cornerRadius = 3

            layer.addSublayer(photoBackgroundLayer)

            return layer;


        case IKImageBrowserCellForegroundLayer:
            if cellState() != IKImageStateReady { return nil }

            let layer = CALayer()
            layer.frame = CGRectMake(0, 0, frame().width, frame().height)
            layer.delegate = self
            layer.setNeedsDisplay()

            return layer;


        case IKImageBrowserCellSelectionLayer:
            let layer = CALayer()
            layer.frame = CGRectMake(0, 0, frame().width, frame().height)

            let fillComponents: [CGFloat] = [0.9, 0.9, 0.9, 0.3]
            let strokeComponents: [CGFloat] = [0.9, 0.9, 0.9, 0.8]

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var color = CGColorCreate(colorSpace, fillComponents)
            layer.backgroundColor = color

            color = CGColorCreate(colorSpace, strokeComponents)
            layer.borderColor = color

            layer.borderWidth = 1.0
            layer.cornerRadius = 5

            return layer;


        default:
            return super.layerForType(type)
        }
    }


    // MARK: drawLayer
    override public func drawLayer(layer: CALayer, inContext ctx: CGContext)
    {
        NSGraphicsContext.saveGraphicsState()

        let gc = NSGraphicsContext(CGContext:ctx, flipped:false)
        NSGraphicsContext.setCurrentContext(gc)

        let lineHeight = 0.5 + ImageBrowserCell.getLineHeight()

        let item = representedItem() as! ThumbnailViewItem

        drawString(item.mediaData.name, x: 4, y: 2, attributes: ImageBrowserCell.textAttrs)
        var y = lineHeight
        if item.mediaData.doFileAndExifTimestampsMatch() {
            drawString(item.mediaData.formattedTime(), x: 4, y: y, attributes: ImageBrowserCell.textAttrs)
        }
        else {
            drawString(item.mediaData.formattedTime(), x: 4, y: y, attributes: ImageBrowserCell.badDateAttrs)
        }

        y = lineHeight * 2
        if item.mediaData.keywordsString().characters.count > 0 {
            drawString(item.mediaData.keywordsString(), x: 4, y: y, attributes: ImageBrowserCell.textAttrs)
        } else {
            drawString("< -- >", x: 4, y: y, attributes: ImageBrowserCell.textAttrs)
        }

        y = lineHeight * 3
        if let location = item.mediaData.location {
            drawString(location.toDecimalDegrees(true), x: 4, y: y, attributes: ImageBrowserCell.textAttrs)
        } else {
            drawString("[ no location ]", x: 4, y: y, attributes: ImageBrowserCell.textAttrs)
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawString(str: String, x: CGFloat, y: CGFloat, attributes: [String:AnyObject]) -> NSRect
    {
        let attrStr = NSMutableAttributedString(string: str, attributes: attributes)
        let bounds = CTLineGetBoundsWithOptions(CTLineCreateWithAttributedString(attrStr), CTLineBoundsOptions.UseHangingPunctuation)

        var updatedX = x
        if x < 0 {
            updatedX = bounds.width + x
        }

        let rect = NSRect(x: updatedX, y: y, width: bounds.width, height: bounds.height - bounds.origin.y)
        attrStr.drawInRect(rect)

        return rect
    }

    // MARK: Frame sizes
    public override func imageFrame() -> NSRect
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

    public override func imageContainerFrame() -> NSRect
    {
        let extraForText = 2 + ImageBrowserCell.getLineHeight() * 2
        let superRect = super.frame()
        let imageFrame = NSRect(x: superRect.origin.x, y: superRect.origin.y + extraForText, width: superRect.width, height: superRect.height - extraForText)

        return imageFrame
    }

    public override func titleFrame() -> NSRect
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

    public override func selectionFrame() -> NSRect
    {
        return NSInsetRect(super.frame(), -3, -3)
    }
    
    // MARK: line height helper
    static private func getLineHeight() -> CGFloat
    {
        if lineHeight == nil {
            let attrStr = NSMutableAttributedString(string: "Mj", attributes: textAttrs)
            lineHeight = CTLineGetBoundsWithOptions(CTLineCreateWithAttributedString(attrStr), CTLineBoundsOptions.UseHangingPunctuation).height
        }
        return lineHeight!
    }
}