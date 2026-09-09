import AppKit
import Foundation

enum LegalLinks {
    static let termsOfUseURL = URL(string: "https://convertitapp.com/legal")!

    static func openTermsOfUse() {
        NSWorkspace.shared.open(termsOfUseURL)
    }
}
