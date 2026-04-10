import SwiftUI
import Textual

struct ThirdPartyNoticesView: View {
    @Environment(\.dismiss) private var dismiss

    private static var noticeText: String {
        if let url = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "md"),
           let s = try? String(contentsOf: url, encoding: .utf8)
        {
            return s
        }
        return
            "Third-party notices could not be loaded from the app bundle. See the StickNote repository for ThirdPartyNotices.md."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Third-party software")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding([.top, .horizontal])

            Divider()
                .padding(.vertical, 8)

            ScrollView {
                StructuredText(Self.noticeText, parser: StickNoteMarkdownParser())
                    .textual.textSelection(.enabled)
                    .textual.structuredTextStyle(StickNoteStructuredTextStyle())
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(minWidth: 520, minHeight: 420)
    }
}

#Preview {
    ThirdPartyNoticesView()
}
