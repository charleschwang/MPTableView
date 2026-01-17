# MPTableView

MPTableView is a UITableView-inspired list view implementation.

This project explores how a UITableView-like system can be built from scratch,
with a strong focus on scrolling performance, update mechanics, and reuse behavior.

Compared to UITableView, this implementation aims to:

- Reduce CPU usage during scrolling and batch updates.
- Keep reusable views lightweight and avoid implicit view hierarchies.
- Provide explicit and customizable animation APIs, including grouped update animations.
- Allow finer control over the reuse lifecycle when needed.
- Support more advanced list view behavior on older versions of iOS.

This project exists primarily as a learning and research effort, and as a playground
for experimenting with list view internals such as layout, reuse, scrolling,
and update reconciliation.

---

### How to Use

MPTableView follows the same core APIs as UITableView.  
For additional features and advanced usage, see the demo project.

---

### Requirements

- Xcode 5 or later
- iOS 7 or later

---

### License

MPTableView is released under the MIT license.  
See the LICENSE file for details.

---

### Maintenance Status

This project has not been under active development for many years.
However, it may still receive updates when necessary to keep compatibility
with system-level changes in iOS.

At the time of writing, MPTableView works well on iOS versions ranging from
iOS 7 to iOS 14.
