//
//  DefinitionView.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 4/24/21.
//

import SwiftUI

// MARK: DWTextView
class DWTextView: NSTextView {
    override var intrinsicContentSize: NSSize {
//        layoutManager!.ensureLayout(for: textContainer!)
//        let size = layoutManager!.usedRect(for: textContainer!).size
//        print("size", size)
//        return size
        print("minSizeForContent", minSizeForContent())
        return minSizeForContent()
//        let textStorage = NSTextStorage(string: string)
//        let textContainer = NSTextContainer(size: NSSize(width: bounds.width, height: 500))
//        let layoutManager = NSLayoutManager()
//
//        layoutManager.addTextContainer(textContainer)
//        textStorage.addLayoutManager(layoutManager)
//        textStorage.addAttribute(.font,
//                                 value: font,
//                                 range: NSRange(location: 0,
//                                                length: (string as NSString).length))
//
//        // Force layout pass
//        textContainer.layoutManager!.glyphRange(for: textContainer)
//        textContainer.lineFragmentPadding = 0
//
//        let rect = layoutManager.usedRect(for: textContainer)
//
//        print(rect)
//
//        return NSSize(
//            width: bounds.width,
//            height: rect.height
//        )
    }
    
    private func minSizeForContent() -> NSSize {
        layoutManager!.boundingRect(forGlyphRange: NSRange(), 
                                    in: textContainer!)
        let usedRect = layoutManager!.usedRect(for: textContainer!)
        let inset = textContainerInset
        return usedRect.insetBy(dx: -inset.width * 2, dy: -inset.height * 2).size
    }
    
//    override func didChangeText() {
//        super.didChangeText()
//        invalidateIntrinsicContentSize()
//    }
}

// MARK: TextView
struct TextView: NSViewRepresentable {
    let text: String
    
    func makeNSView(context: Context) -> NSTextView {
        let view = DWTextView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.string = text
        view.wantsLayer = true
//        view.layer?.backgroundColor = NSColor.systemOrange.cgColor
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.translatesAutoresizingMaskIntoConstraints = true
        view.textContainerInset = NSSize(width: 0, height: 10)
        view.textContainer!.widthTracksTextView = true
        view.textContainer!.heightTracksTextView = true
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        view.defaultParagraphStyle = style
        view.backgroundColor = NSColor.clear
        view.isEditable = false
        let font = NSFont.preferredFont(forTextStyle: .body)
        var descriptor = font.fontDescriptor
        descriptor = descriptor.withDesign(.serif)!
        view.font = NSFont(descriptor: descriptor, size: font.pointSize)
        
        return view
    }
    
    func updateNSView(_ nsView: NSTextView, context: Context) {
//        nsView.string = "\(nsView.frame)"
    }
    
    typealias NSViewType = NSTextView
}

// MARK: DWDefinitionsView
class DWDefinitionsView: NSView {
    let definitions: [Definition]

    init(definitions: [Definition], frame frameRect: NSRect) {
        self.definitions = definitions
        super.init(frame: frameRect)
        setUpView()
    }
    
    @available(*, unavailable)
    override init(frame frameRect: NSRect) {
        definitions = []
        super.init(frame: frameRect)
        setUpView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        definitions = []
        super.init(coder: coder)
        setUpView()
    }
    
    private func setUpView()  {
        let scrollView = NSScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
//        scrollView.backgroundColor = NSColor.red
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
        ])
        
        let stack = NSStackView(frame: .zero)
        stack.orientation = .vertical
        stack.distribution = .equalSpacing
        stack.alignment = .leading
        stack.wantsLayer = true
        stack.layer?.backgroundColor = NSColor.red.cgColor
//        let stack = NSBox()
//        stack.fillColor = .systemRed
        stack.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
//            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
//            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
//            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
//            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
//        ])
        definitions
            .map { definition -> NSView in
                let textView = DWTextView()
                textView.string = definition.expansion.principleParts + "\n" + definition.meaning
                textView.backgroundColor = .systemBlue
                return textView
            }
            .forEach {
                stack.addArrangedSubview($0)
//                stack.setContentHuggingPriority(.required, for: .horizontal)
//                stack.setHuggingPriority(.required, for: .horizontal)
//                stack.setContentCompressionResistancePriority(.required, for: .horizontal)
                $0.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            }
        scrollView.documentView = stack
        stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
    }
}

// MARK: DefinitionsView
struct DefinitionsView: View {
    let definitions: ([Definition], Bool)
    
    @State
    var showingTruncationInfo = false
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(definitions.0) {
                    DefinitionView(definition: $0)
                }
            }
            
            if definitions.1 {
                HStack {
                    Text("additional results truncated")
                        .foregroundColor(.secondary)
                        .font(.system(.footnote))
                        .italic()
                    Button(action: { self.showingTruncationInfo.toggle() }, label: {
                        Image(systemName: "info.circle")
                    })
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.secondary)
                    .popover(isPresented: $showingTruncationInfo) {
                        HStack(alignment: .top) {
                            Text("By default, the WORDS program filters out additional results that are very unlikely. For more information, see iWords Help.")
                        }
                            .foregroundColor(.secondary)
                            .padding(6)
                            .frame(width: 200)
                            .font(.footnote)
                            .visualEffect(material: .popover, emphasized: true)
                    }
                }
            }
        }
    }
}

// MARK: DefinitionView
struct DefinitionView: View {
    let definition: Definition

    @State
    var showDeclensions = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(verbatim: definition.expansion.principleParts)
                .font(.system(.title, design: .serif))
                .fontWeight(.medium)
            Group {
                switch definition.expansion {
                case .noun(_, let declension, let gender):
                    Text("\(definition.expansion.pos.description), \(declension.description), \(gender.description)")
                case .verb(_, let conjugation):
                    Text("\(definition.expansion.pos.description), \(conjugation.description)")
                case .adj:
                    Text("\(definition.expansion.pos.description)")
                }
            }
                .foregroundColor(.secondary)
                .font(.system(.callout, design: .serif))

            Text(definition.possibilities.map(\.debugDescription).joined(separator: "\n"))
                .multilineTextAlignment(.leading)
                .font(.system(.caption2, design: .serif))
//                .font(.system(.caption, design: .monospaced))

            Rectangle().fill(SeparatorShapeStyle())
                .frame(height: 1)
                
            TextView(text: definition.meaning)

            DisclosureGroup("Declensions", isExpanded: $showDeclensions) {
                VStack(alignment: .leading) {
                    Text(definition.possibilities.map(\.debugDescription).joined(separator: "\n"))
                        .multilineTextAlignment(.leading)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .visualEffect(material: .contentBackground)
    }
}

// MARK: DWBridgedDefinitionView
struct DWBridgedDefinitionView: NSViewRepresentable {
    let definitions: [Definition] 
    
    func makeNSView(context: Context) -> NSView {
        let view = DWDefinitionsView(definitions: definitions, frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // do nothing
    }
}

// MARK: DefinitionView_Previews
struct DefinitionView_Previews: PreviewProvider {
    static let noun = iWords.Definition(possibilities: ["copi.a               N      1 1 NOM S F                 ", "copi.a               N      1 1 VOC S F                 ", "copi.a               N      1 1 ABL S F                 "].compactMap(possibility.parse),
                                        expansion: .noun("copia, copiae", .first, .feminine),
                                        meaning: "plenty, abundance, supply; troops (pl.), supplies; forces; resources; wealth; number/amount/quantity; sum/whole amount; means, opportunity; access/admission;")
    
    static let verb = iWords.Definition(
        possibilities: ["consul.ere           V      3 1 PRES ACTIVE  INF 0 X    ", 
                        "consul.ere           V      3 1 PRES PASSIVE IMP 2 S    ",
                        "consul.ere           V      3 1 FUT  PASSIVE IND 2 S    "].compactMap(possibility.parse),
        expansion: .verb("consulo, consulere, consului, consultus", 
            .third), 
        meaning: "ask information/advice of; consult, take counsel; deliberate/consider; advise; decide upon, adopt; look after/out for (DAT), pay attention to; refer to;*",
        truncated: true)
    
    static var previews: some View {
        Group {
            DefinitionsView(definitions: ([noun, verb], true))
//            DWBridgedDefinitionView(definitions: [noun, verb])
                .frame(width: 500, height: 500, alignment: .center)
        }
    }
}
