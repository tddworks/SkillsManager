import SwiftUI
import Markdown

/// Renders markdown content as styled SwiftUI views
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
        VStack(alignment: .leading, spacing: 12) {
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
            Divider()
                .padding(.vertical, 8)

        case let htmlBlock as HTMLBlock:
            Text(htmlBlock.rawHTML)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

        default:
            Text(markup.format())
                .font(.body)
        }
    }
}

// MARK: - Block Views

struct HeadingView: View {
    let heading: Heading

    var body: some View {
        Text(heading.plainText)
            .font(fontForLevel(heading.level))
            .fontWeight(.bold)
            .padding(.top, heading.level == 1 ? 0 : 8)
    }

    private func fontForLevel(_ level: Int) -> Font {
        switch level {
        case 1: return .largeTitle
        case 2: return .title
        case 3: return .title2
        case 4: return .title3
        case 5: return .headline
        default: return .subheadline
        }
    }
}

struct ParagraphView: View {
    let paragraph: Paragraph

    var body: some View {
        Text(attributedString(for: paragraph))
            .font(.body)
            .lineSpacing(4)
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
            attr.font = .body.bold()
            return attr

        case let emphasis as Emphasis:
            var attr = AttributedString(emphasis.plainText)
            attr.font = .body.italic()
            return attr

        case let code as InlineCode:
            var attr = AttributedString(code.code)
            attr.font = .system(.body, design: .monospaced)
            attr.backgroundColor = Color(nsColor: .quaternaryLabelColor)
            return attr

        case let link as Markdown.Link:
            var attr = AttributedString(link.plainText)
            attr.foregroundColor = .accentColor
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language label if present
            if let language = codeBlock.language, !language.isEmpty {
                Text(language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(codeBlock.code.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}

struct UnorderedListView: View {
    let list: UnorderedList

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(list.children.enumerated()), id: \.offset) { _, item in
                if let listItem = item as? ListItem {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
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
        .padding(.leading, 8)
    }
}

struct OrderedListView: View {
    let list: OrderedList

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(list.children.enumerated()), id: \.offset) { index, item in
                if let listItem = item as? ListItem {
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 4) {
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
        .padding(.leading, 8)
    }
}

struct BlockQuoteView: View {
    let blockQuote: BlockQuote

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.5))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(blockQuote.children.enumerated()), id: \.offset) { _, child in
                    if let para = child as? Paragraph {
                        ParagraphView(paragraph: para)
                    }
                }
            }
            .padding(.leading, 12)
        }
        .padding(.vertical, 4)
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
