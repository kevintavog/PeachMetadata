//
//  PeachMetadata
//

import Quartz

open class ImageBrowserView : IKImageBrowserView
{
    open override func newCell(forRepresentedItem item: Any!) -> IKImageBrowserCell!
    {
        return ImageBrowserCell()
    }
}
