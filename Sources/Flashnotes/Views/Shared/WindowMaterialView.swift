import SwiftUI

/// Solid navigation surface shared by the library and note-outline sidebars.
struct SidebarMaterialBackground: View {
    var body: some View {
        Color(nsColor: .windowBackgroundColor)
            .ignoresSafeArea()
    }
}
