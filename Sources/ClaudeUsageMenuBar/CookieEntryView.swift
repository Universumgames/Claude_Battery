import SwiftUI

struct CookieEntryView: View {
    @State private var cookieInput: String = ""
    let onSave: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set claude.ai session cookie")
                .font(.headline)
            Text("On claude.ai: open DevTools → Application → Cookies → claude.ai, copy the value of **sessionKey**, then paste it below.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            SecureField("sessionKey value", text: $cookieInput)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    guard !cookieInput.isEmpty else { return }
                    onSave(cookieInput)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(cookieInput.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
