import SwiftUI

/// A background image that fills the screen edge to edge without pushing layout around.
///
/// A bare `Image` in `.fill` mode reports its scaled size to the layout system and drags its
/// container past the screen bounds. Painting it into a zero-size `Color.clear` and clipping
/// there keeps it purely decorative.
struct FullBleedImage: View {
    let name: String

    var body: some View {
        Color.clear
            .overlay {
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .clipped()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
