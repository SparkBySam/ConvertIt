import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView<Content: View>: View {
    @Binding var isTargeted: Bool
    let content: Content

    init(isTargeted: Binding<Bool>, @ViewBuilder content: () -> Content) {
        _isTargeted = isTargeted
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: 72)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [6, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                    )
            }
    }
}

enum DropURLLoader {
    static func load(from providers: [NSItemProvider]) async -> [URL] {
        await withTaskGroup(of: URL?.self) { group in
            for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.addTask {
                    await loadURL(from: provider)
                }
            }

            var urls: [URL] = []
            for await url in group {
                if let url {
                    urls.append(url)
                }
            }
            return urls
        }
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }
}
