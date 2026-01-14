import SwiftUI
import Markdown

/// Renders markdown content as styled SwiftUI views with refined typography
struct MarkdownView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let document = Document(parsing: content)
            MarkdownRenderer(document: document)
        }
    }
}

/// Renders a Markdown document as SwiftUI views
struct MarkdownRenderer: View {
    let document: Document

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            ForEach(Array(document.children.enumerated()), id: \.offset) { _, child in
                renderBlock(child)
            }
        }
    }

    @ViewBuilder
    private func renderBlock(_ markup: Markup) -> some View {
        switch markup {
        case let heading as Heading:
            HeadingView(heading: heading)

        case let paragraph as Paragraph:
            ParagraphView(paragraph: paragraph)

        case let codeBlock as CodeBlock:
            CodeBlockView(codeBlock: codeBlock)

        case let list as UnorderedList:
            UnorderedListView(list: list)

        case let list as OrderedList:
            OrderedListView(list: list)

        case let blockQuote as BlockQuote:
            BlockQuoteView(blockQuote: blockQuote)

        case _ as ThematicBreak:
            Rectangle()
                .fill(DesignSystem.Colors.subtleBorder)
                .frame(height: 1)
                .padding(.vertical, DesignSystem.Spacing.md)

        case let htmlBlock as HTMLBlock:
            Text(htmlBlock.rawHTML)
                .font(DesignSystem.Typography.code)
                .foregroundStyle(DesignSystem.Colors.secondaryText)

        default:
            Text(markup.format())
                .font(DesignSystem.Typography.body)
        }
    }
}

// MARK: - Block Views

struct HeadingView: View {
    let heading: Heading

    var body: some View {
        Text(heading.plainText)
            .font(fontForLevel(heading.level))
            .fontWeight(.semibold)
            .foregroundStyle(DesignSystem.Colors.primaryText)
            .padding(.top, topPadding)
            .padding(.bottom, DesignSystem.Spacing.xs)
    }

    private func fontForLevel(_ level: Int) -> Font {
        switch level {
        case 1: return .system(size: 24, weight: .bold, design: .rounded)
        case 2: return .system(size: 20, weight: .semibold, design: .rounded)
        case 3: return .system(size: 17, weight: .semibold, design: .rounded)
        case 4: return .system(size: 15, weight: .semibold, design: .default)
        case 5: return .system(size: 14, weight: .semibold, design: .default)
        default: return .system(size: 13, weight: .semibold, design: .default)
        }
    }

    private var topPadding: CGFloat {
        switch heading.level {
        case 1: return DesignSystem.Spacing.sm
        case 2: return DesignSystem.Spacing.lg
        default: return DesignSystem.Spacing.md
        }
    }
}

struct ParagraphView: View {
    let paragraph: Paragraph

    var body: some View {
        Text(attributedString(for: paragraph))
            .font(DesignSystem.Typography.body)
            .lineSpacing(5)
            .foregroundStyle(DesignSystem.Colors.primaryText)
    }

    private func attributedString(for paragraph: Paragraph) -> AttributedString {
        var result = AttributedString()

        for child in paragraph.children {
            result.append(renderInline(child))
        }

        return result
    }

    private func renderInline(_ markup: Markup) -> AttributedString {
        switch markup {
        case let text as Markdown.Text:
            return AttributedString(text.string)

        case let strong as Strong:
            var attr = AttributedString(strong.plainText)
            attr.font = .system(size: 13, weight: .semibold)
            return attr

        case let emphasis as Emphasis:
            var attr = AttributedString(emphasis.plainText)
            attr.font = .system(size: 13).italic()
            return attr

        case let code as InlineCode:
            var attr = AttributedString(code.code)
            attr.font = DesignSystem.Typography.code
            attr.backgroundColor = DesignSystem.Colors.badgeBackground
            return attr

        case let link as Markdown.Link:
            var attr = AttributedString(link.plainText)
            attr.foregroundColor = DesignSystem.Colors.accent
            attr.underlineStyle = .single
            if let url = link.destination {
                attr.link = URL(string: url)
            }
            return attr

        case _ as SoftBreak:
            return AttributedString(" ")

        case _ as LineBreak:
            return AttributedString("\n")

        default:
            return AttributedString(markup.format())
        }
    }
}

struct CodeBlockView: View {
    let codeBlock: CodeBlock

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language label if present
            if let language = codeBlock.language, !language.isEmpty {
                HStack {
                    Text(language.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                    Spacer()

                    // Copy button on hover
                    if isHovering {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(codeBlock.code, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.tertiaryText)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.xs)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(codeBlock.code.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(DesignSystem.Typography.code)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .textSelection(.enabled)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.md)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                        .stroke(DesignSystem.Colors.subtleBorder, lineWidth: 1)
                )
        )
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovering = hovering
            }
        }
    }
}

struct UnorderedListView: View {
    let list: UnorderedList

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(Array(list.children.enumerated()), id: \.offset) { _, item in
                if let listItem = item as? ListItem {
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        Circle()
                            .fill(DesignSystem.Colors.tertiaryText)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            ForEach(Array(listItem.children.enumerated()), id: \.offset) { _, child in
                                if let para = child as? Paragraph {
                                    ParagraphView(paragraph: para)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.leading, DesignSystem.Spacing.sm)
    }
}

struct OrderedListView: View {
    let list: OrderedList

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(Array(list.children.enumerated()), id: \.offset) { index, item in
                if let listItem = item as? ListItem {
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        Text("\(index + 1).")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .frame(width: 20, alignment: .trailing)

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            ForEach(Array(listItem.children.enumerated()), id: \.offset) { _, child in
                                if let para = child as? Paragraph {
                                    ParagraphView(paragraph: para)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.leading, DesignSystem.Spacing.sm)
    }
}

struct BlockQuoteView: View {
    let blockQuote: BlockQuote

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignSystem.Colors.accent.opacity(0.6))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ForEach(Array(blockQuote.children.enumerated()), id: \.offset) { _, child in
                    if let para = child as? Paragraph {
                        ParagraphView(paragraph: para)
                    }
                }
            }
            .padding(.leading, DesignSystem.Spacing.md)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - Helper Extensions

extension Markup {
    var plainText: String {
        var result = ""
        for child in children {
            if let text = child as? Markdown.Text {
                result += text.string
            } else {
                result += child.plainText
            }
        }
        return result
    }
}
