//
//  PeachMetadata
//

import Quartz

public class ImageBrowserView : IKImageBrowserView
{
    public override func newCellForRepresentedItem(item: AnyObject!) -> IKImageBrowserCell!
    {
        return ImageBrowserCell()
    }
}