import AppKit
import SwiftUI

/// Font row: family list in a popover (search, monospaced filter), face picker, size field.
struct FontListPicker: View {
    @Binding var font: NSFont
    @State private var showingFamilies = false

    private var family: String { font.familyName ?? font.fontName }

    private var faces: [(postscript: String, name: String)] {
        (NSFontManager.shared.availableMembers(ofFontFamily: family) ?? []).compactMap { member in
            guard let postscript = member.first as? String else { return nil }
            let name = member.count > 1 ? (member[1] as? String ?? postscript) : postscript
            return (postscript, name)
        }
    }

    private var sizeBinding: Binding<Double> {
        Binding(
            get: { Double(font.pointSize) },
            set: { font = font.withSize(CGFloat(min(96, max(8, $0.rounded())))) }
        )
    }

    var body: some View {
        LabeledContent("Font") {
            HStack(spacing: 6) {
                Button {
                    showingFamilies.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(FontFamilies.displayName(family))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 150)
                }
                .popover(isPresented: $showingFamilies, arrowEdge: .bottom) {
                    FontFamilyList(selected: family) { newFamily in
                        font = NSFontManager.shared.convert(font, toFamily: newFamily)
                        showingFamilies = false
                    }
                }

                if faces.count > 1 {
                    Picker("Face", selection: Binding(
                        get: { font.fontName },
                        set: { name in
                            if let f = NSFont(name: name, size: font.pointSize) { font = f }
                        }
                    )) {
                        ForEach(faces, id: \.postscript) { face in
                            Text(face.name).tag(face.postscript)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                TextField("Size", value: sizeBinding, format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 36)
                Stepper("Size", value: sizeBinding, in: 8...96)
                    .labelsHidden()
            }
        }
    }
}

private struct FontFamilyList: View {
    let selected: String
    let onPick: (String) -> Void

    @State private var query = ""
    @State private var monospacedOnly = false

    private var visible: [FontFamilies.Entry] {
        FontFamilies.all.filter { entry in
            (!monospacedOnly || entry.isMonospaced)
                && (query.isEmpty || entry.displayName.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            TextField("Search fonts", text: $query)
                .textFieldStyle(.roundedBorder)
            Picker("Filter", selection: $monospacedOnly) {
                Text("All").tag(false)
                Text("Monospaced").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            ScrollViewReader { proxy in
                List(visible) { entry in
                    let isSelected = entry.family == selected
                    Text(entry.displayName)
                        .font(Font(entry.previewFont))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isSelected ? Color.accentColor : Color.clear)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { onPick(entry.family) }
                        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                        .listRowSeparator(.hidden)
                        .id(entry.family)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .onAppear { proxy.scrollTo(selected, anchor: .center) }
            }
        }
        .padding(10)
        .frame(width: 280, height: 360)
        // The popover inherits trailing alignment from the form row.
        .multilineTextAlignment(.leading)
    }
}

/// Installed families, read once. Fonts installed while the app runs show up after relaunch.
enum FontFamilies {
    struct Entry: Identifiable {
        let family: String
        let displayName: String
        let previewFont: NSFont
        let isMonospaced: Bool
        var id: String { family }
    }

    static let all: [Entry] = NSFontManager.shared.availableFontFamilies
        .filter { !$0.hasPrefix(".") }
        .compactMap { family in
            guard
                let base = NSFontManager.shared.font(
                    withFamily: family, traits: [], weight: 5, size: 14)
            else { return nil }
            // Symbol fonts render their names as pictographs; show those in the system font.
            let readable = base.coveredCharacterSet.isSuperset(of: CharacterSet(charactersIn: "AaZz"))
            return Entry(
                family: family,
                displayName: displayName(family),
                previewFont: readable ? base : .systemFont(ofSize: 14),
                isMonospaced: base.isFixedPitch || base.fontDescriptor.symbolicTraits.contains(.monoSpace)
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

    static func displayName(_ family: String) -> String {
        NSFontManager.shared.localizedName(forFamily: family, face: nil)
    }
}
