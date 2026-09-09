import AppKit
import SwiftUI

private enum AppMetadata {
    static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        if build.isEmpty || build == version {
            return "Version \(version)"
        }
        return "Version \(version) (\(build))"
    }

    static var copyrightString: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? ""
    }

    static var appIcon: NSImage? {
        if let icon = NSApplication.shared.applicationIconImage, icon.size.width > 0 {
            return icon
        }
        return NSImage(named: NSImage.applicationIconName)
    }
}

struct AboutView: View {
    var onClose: () -> Void

    private let cornerRadius: CGFloat = 10
    private let amberFill = Color(red: 0.82, green: 0.58, blue: 0.18).opacity(0.32)
    private let amberText = Color(red: 0.98, green: 0.82, blue: 0.48)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.bottom, 6)

            VStack(spacing: 16) {
                appIconView

                Text("ConvertIt")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(AppMetadata.versionString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !AppMetadata.copyrightString.isEmpty {
                    Text(AppMetadata.copyrightString)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }

                Text("Unit, currency, and media conversion — right from your menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)

                Button(action: openTipJar) {
                    Text("☕ Buy me a coffee")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(amberText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(amberFill, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                Button(action: openFeedback) {
                    Label("Send feedback or feature requests", systemImage: "envelope")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.82))
                }
                .buttonStyle(.plain)

                Button(action: LegalLinks.openTermsOfUse) {
                    Label("Terms of Use & licenses", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.82))
                }
                .buttonStyle(.plain)

                VStack(spacing: 6) {
                    Text(FFmpegCompliance.aboutNotice)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Button(action: openFFmpegSource) {
                            Text("FFmpeg source")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Button(action: openFFmpegLicense) {
                            Text("LGPLv2.1")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Exchange rates via Frankfurter")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 2)

                Text("Built by Sam Parker")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Button(action: openSparkSuite) {
                    Text("Part of the Spark Suite")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(22)
        .frame(width: 300)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .onExitCommand(perform: onClose)
    }

    @ViewBuilder
    private var appIconView: some View {
        if let icon = AppMetadata.appIcon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 88, height: 88)
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
    }

    private func openTipJar() {
        openURL("https://buymeacoffee.com/sparkdev")
    }

    private func openFeedback() {
        openURL("mailto:help@convertitapp.com")
    }

    private func openFFmpegSource() {
        openURL(FFmpegCompliance.sourceDownloadURL.absoluteString)
    }

    private func openFFmpegLicense() {
        openURL(FFmpegCompliance.lgplURL.absoluteString)
    }

    private func openSparkSuite() {
        openURL("https://sparksuiteapps.com")
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}

struct AboutPanelOverlay: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                Color.black.opacity(0.45)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isPresented = false
                    }

                AboutView {
                    isPresented = false
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: isPresented)
    }
}

extension View {
    func aboutPanel(isPresented: Binding<Bool>) -> some View {
        modifier(AboutPanelOverlay(isPresented: isPresented))
    }
}

#Preview {
    AboutView(onClose: {})
        .padding()
        .background(Color.black.opacity(0.5))
}
