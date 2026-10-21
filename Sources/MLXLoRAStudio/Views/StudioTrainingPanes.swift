import SwiftUI

/// Presentation only. Both panes keep their own scroll views and job bindings.
struct StudioTrainingPanes<Settings: View, Console: View>: View {
    let available: CGSize
    let collapsed: Bool
    @ViewBuilder var settings: () -> Settings
    @ViewBuilder var console: () -> Console

    var body: some View {
        if collapsed {
            HStack(spacing: 0) {
                settings().frame(maxWidth: .infinity, maxHeight: .infinity)
                // The rail's 56 pt body includes another 16 pt on each side.
                console().frame(width: 88)
            }
        } else if available.width >= 1000 {
            HSplitView {
                settings()
                    .frame(minWidth: 520, idealWidth: available.width * 0.6,
                           maxWidth: .infinity, maxHeight: .infinity)
                console()
                    .frame(minWidth: 360, idealWidth: available.width * 0.4,
                           maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            // A narrow window cannot fit readable settings and logs side by side.
            VSplitView {
                settings()
                    .frame(maxWidth: .infinity, minHeight: 200,
                           idealHeight: available.height * 0.55, maxHeight: .infinity)
                console()
                    .frame(maxWidth: .infinity, minHeight: 280,
                           idealHeight: available.height * 0.45, maxHeight: .infinity)
            }
        }
    }
}
