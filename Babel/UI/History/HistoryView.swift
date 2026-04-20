import AppKit
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Dictation.createdAt, order: .reverse)])
    private var dictations: [Dictation]

    @State private var selection: Dictation.ID?

    var body: some View {
        NavigationSplitView {
            if dictations.isEmpty {
                emptyState
                    .frame(minWidth: 260)
            } else {
                List(selection: $selection) {
                    ForEach(dictations) { dictation in
                        HistoryRow(dictation: dictation)
                            .tag(dictation.id)
                            .contextMenu {
                                Button("Copy text") { copy(dictation) }
                                Button("Re-insert") { reinsert(dictation) }
                                Divider()
                                Button("Delete", role: .destructive) { delete(dictation) }
                            }
                    }
                }
                .listStyle(.inset)
                .frame(minWidth: 260)
            }
        } detail: {
            if let selected = dictations.first(where: { $0.id == selection }) {
                HistoryDetailView(dictation: selected, onCopy: copy, onReinsert: reinsert, onDelete: delete)
            } else {
                ContentUnavailableView("Pick a dictation", systemImage: "waveform", description: Text("Your history lives here. Select an entry to see its details."))
            }
        }
        .frame(minWidth: 640, minHeight: 420)
        .navigationTitle("Babel History")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.tint)
            Text("No dictations yet")
                .font(.headline)
            Text("Hold Right Option anywhere on macOS to record your first one.")
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

    private func reinsert(_ dictation: Dictation) {
        // The active app is whatever was focused before the history window opened.
        // We hide our window, hop back to the previous app, and inject.
        NSApp.hide(nil)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            _ = TextInserter.insert(dictation.finalText)
        }
    }

    private func delete(_ dictation: Dictation) {
        modelContext.delete(dictation)
        try? modelContext.save()
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
    let onReinsert: (Dictation) -> Void
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
                Button {
                    onReinsert(dictation)
                } label: {
                    Label("Re-insert", systemImage: "text.insert")
                }
                Button(role: .destructive) {
                    onDelete(dictation)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
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
