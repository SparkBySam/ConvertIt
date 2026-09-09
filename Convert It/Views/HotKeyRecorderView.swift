import AppKit
import Carbon
import SwiftUI

struct HotKeyRecorderView: View {
    @Binding var hotkey: GlobalHotKey
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                isRecording.toggle()
            } label: {
                Text(isRecording ? "Press shortcut…" : hotkey.displayString)
                    .font(.body.monospaced())
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        isRecording ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)

            Button("Reset") {
                hotkey = .default
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .background {
            HotKeyCaptureRepresentable(isRecording: $isRecording, hotkey: $hotkey)
                .frame(width: 0, height: 0)
        }
    }
}

private struct HotKeyCaptureRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var hotkey: GlobalHotKey

    func makeNSView(context: Context) -> HotKeyCaptureView {
        let view = HotKeyCaptureView()
        view.onCapture = { captured in
            hotkey = captured
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: HotKeyCaptureView, context: Context) {
        nsView.isRecording = isRecording
    }
}

private final class HotKeyCaptureView: NSView {
    var isRecording = false {
        didSet {
            if isRecording {
                window?.makeFirstResponder(self)
                installMonitor()
            } else {
                removeMonitor()
            }
        }
    }

    var onCapture: ((GlobalHotKey) -> Void)?
    var onCancel: (() -> Void)?

    private var monitor: Any?

    override var acceptsFirstResponder: Bool { true }

    deinit {
        removeMonitor()
    }

    private func installMonitor() {
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, self.isRecording else { return event }

            if event.type == .keyDown {
                if event.keyCode == UInt16(kVK_Escape) {
                    self.onCancel?()
                    return nil
                }
                if let captured = GlobalHotKey.from(event: event), captured.isValid {
                    self.onCapture?(captured)
                    return nil
                }
            }
            return event
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

#Preview {
    HotKeyRecorderView(hotkey: .constant(.default))
        .padding()
        .frame(width: 280)
}
