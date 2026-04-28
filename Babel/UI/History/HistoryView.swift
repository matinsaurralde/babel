import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Dictation.createdAt, order: .reverse)])
    private var allDictations: [Dictation]

    @State private var selection: Dictation.ID?
    @State private var searchText: String = ""

    private var dictations: [Dictation] {
        guard !searchText.isEmpty else { return allDictations }
        return allDictations.filter {
            $0.finalText.localizedCaseInsensitiveContains(searchText)
                || $0.engineName.localizedCaseInsensitiveContains(searchText)
                || $0.mode.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            Group {
                if allDictations.isEmpty {
                    emptyState
                } else if dictations.isEmpty {
                    ContentUnavailableView.search
                } else {
                    List(selection: $selection) {
                        ForEach(dictations) { dictation in
                            HistoryRow(dictation: dictation)
                                .tag(dictation.id)
                                .contextMenu {
                                    Button("Copy") { copy(dictation) }
                                    Button("Export…") { export(dictation) }
                                    Divider()
                                    Button("Delete", role: .destructive) { delete(dictation) }
                                }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 280)
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search transcripts")
        } detail: {
            if let selected = dictations.first(where: { $0.id == selection }) {
                HistoryDetailView(
                    dictation: selected,
                    onCopy: copy,
                    onExport: export,
                    onDelete: delete
                )
            } else if !allDictations.isEmpty {
                ContentUnavailableView(
                    "Pick a dictation",
                    systemImage: "waveform",
                    description: Text("Select an entry on the left to see its details.")
                )
            } else {
                ContentUnavailableView(
                    "No dictations yet",
                    systemImage: "waveform",
                    description: Text("Hold the push-to-hold key to record your first one.")
                )
            }
        }
        .frame(minWidth: 720, minHeight: 460)
        .navigationTitle("Babel History")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.tint)
            Text("No dictations yet")
                .font(.headline)
            Text("Hold the push-to-hold key anywhere on macOS to record your first one.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding(40)
    }

    private func copy(_ dictation: Dictation) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(dictation.finalText, forType: .string)
    }

    private func delete(_ dictation: Dictation) {
        modelContext.delete(dictation)
        try? modelContext.save()
    }

    private func export(_ dictation: Dictation) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText, UTType("net.daringfireball.markdown") ?? .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultExportFilename(for: dictation)
        panel.title = "Export transcript"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let body = exportBody(for: dictation, asMarkdown: url.pathExtension.lowercased() == "md")
        do {
            try body.data(using: .utf8)?.write(to: url, options: .atomic)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func defaultExportFilename(for d: Dictation) -> String {
        let stamp = ISO8601DateFormatter().string(from: d.createdAt)
            .replacingOccurrences(of: ":", with: "-")
        return "babel-\(stamp).txt"
    }

    private func exportBody(for d: Dictation, asMarkdown: Bool) -> String {
        if asMarkdown {
            return """
            # Babel transcript

            - Mode: **\(d.mode.displayName)**
            - Engine: \(d.engineName)
            - Recorded: \(d.createdAt.formatted(date: .abbreviated, time: .standard))
            - Duration: \(String(format: "%.1f s", d.durationSeconds))

            ---

            \(d.finalText)
            """
        }
        return d.finalText
    }
}

private struct HistoryRow: View {
    let dictation: Dictation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: dictation.mode.sfSymbol)
                    .foregroundStyle(.tint)
                    .font(.caption.weight(.semibold))
                Text(dictation.mode.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(dictation.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(dictation.finalText)
                .lineLimit(2)
                .font(.system(.body, design: .rounded))
        }
        .padding(.vertical, 4)
    }
}

private struct HistoryDetailView: View {
    let dictation: Dictation
    let onCopy: (Dictation) -> Void
    let onExport: (Dictation) -> Void
    let onDelete: (Dictation) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                metadata
                transcript
                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    onCopy(dictation)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .help("Copy the transcript to the clipboard")

                Button {
                    onExport(dictation)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Save the transcript as a .txt or .md file")

                Button(role: .destructive) {
                    onDelete(dictation)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .help("Remove this entry from history")
            }
        }
    }

    private var metadata: some View {
        HStack(spacing: 18) {
            Label(dictation.mode.displayName, systemImage: dictation.mode.sfSymbol)
            Label(String(format: "%.1fs", dictation.durationSeconds), systemImage: "clock")
            Label(dictation.engineName, systemImage: "cpu")
            Spacer()
            Text(dictation.createdAt.formatted(date: .abbreviated, time: .standard))
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var transcript: some View {
        Text(dictation.finalText)
            .font(.system(.title3, design: .rounded))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
