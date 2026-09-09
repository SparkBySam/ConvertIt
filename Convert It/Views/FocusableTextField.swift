import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FocusableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var focusToken: UUID
    var onReturn: (() -> Void)?

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: "")
        field.placeholderString = placeholder
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.delegate = context.coordinator
        field.focusRingType = .default
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.onReturn = onReturn
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onReturn: onReturn)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        var onReturn: (() -> Void)?
        var lastFocusToken: UUID?

        init(text: Binding<String>, onReturn: (() -> Void)?) {
            _text = text
            self.onReturn = onReturn
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onReturn?()
                return true
            }
            return false
        }
    }
}

struct FileDragModifier: ViewModifier {
    let url: URL?

    func body(content: Content) -> some View {
        if let url {
            content.onDrag {
                NSItemProvider(object: url as NSURL)
            }
        } else {
            content
        }
    }
}

extension View {
    func draggableFile(_ url: URL?) -> some View {
        modifier(FileDragModifier(url: url))
    }
}
