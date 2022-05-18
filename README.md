## MPTableView
I haven't worked in software development since 2017, but i still will update this project. For now, MPTableView works well in iOS 7 to iOS 14.

- Lower CPU usage than the UITableView when scrolling or updating.

- Lightweight subviews (neither MPTableViewCell nor MPTableReusableView has subviews). The UITableViewCell has some useless subviews, they needlessly take up memory and CPU time.

- Provide custom animation and group animation APIs for updating.

- You can manually manage the reuse views.

- Support more advanced features in lower versions of iOS.

## How to use
The same APIs as the UITableView. For more new features, see the demo.

## Requirements
Xcode 5+  
iOS 7+

## License
MPTableView is available under the MIT license. See the LICENSE file for more info.
