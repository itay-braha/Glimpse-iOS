import SwiftUI

struct AvatarView: View {
    let name: String
    var imageURL: URL?
    var size: CGFloat = 52
    var ringColor: Color?

    var body: some View {
        ZStack {
            Circle().fill(Palette.seededGradient(name))
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    }
                }
                .clipShape(.circle)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            if let ringColor {
                Circle().strokeBorder(ringColor, lineWidth: 2.5).padding(-4)
            }
        }
        .accessibilityHidden(true)
    }
}
