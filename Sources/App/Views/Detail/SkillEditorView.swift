import SwiftUI
import Domain

/// Side-by-side skill editor with live markdown preview
struct SkillEditorView: View {
    @Bindable var library: SkillLibrary

    var body: some View {
        if let editor = library.skillEditor {
            HSplitView {
                // Left: Editor pane
                editorPane(editor: editor)

                // Right: Preview pane
                previewPane(editor: editor)
            }
            .frame(minWidth: 800)
            .navigationTitle("Editing: \(editor.original.name)")
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Cancel") {
                        library.cancelEditing()
                    }
                    .keyboardShortcut(.cancelAction)
                }

                ToolbarItemGroup(placement: .confirmationAction) {
                    Button {
                        Task { await library.saveEditing() }
                    } label: {
                        Text(editor.isDirty ? "Save" : "Done")
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!editor.isDirty)
                }
            }
        }
    }

    // MARK: - Editor Pane

    private func editorPane(editor: SkillEditor) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Editor", systemImage: "pencil")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)

                Spacer()

                if editor.isDirty {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Circle()
                            .fill(DesignSystem.Colors.warning)
                            .frame(width: 6, height: 6)
                        Text("Modified")
                            .font(DesignSystem.Typography.micro)
                            .foregroundStyle(DesignSystem.Colors.warning)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.cardBackground)

            Divider()

            // TextEditor
            TextEditor(text: Binding(
                get: { editor.draft },
                set: { editor.draft = $0 }
            ))
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    // MARK: - Preview Pane

    private func previewPane(editor: SkillEditor) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Preview", systemImage: "eye")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.cardBackground)

            Divider()

            // Live MarkdownView preview
            ScrollView {
                MarkdownView(content: editor.draft)
                    .padding(DesignSystem.Spacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
}
