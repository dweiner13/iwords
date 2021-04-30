//
//  DefinitionView.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 4/24/21.
//

import SwiftUI

class DWTextView: NSTextView {
    override var intrinsicContentSize: NSSize {
        let textStorage = NSTextStorage(string: string)
        let textContainer = NSTextContainer(size: NSSize(width: bounds.width, height: 500))
        let layoutManager = NSLayoutManager()

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        textStorage.addAttribute(.font, 
                                 value: font, 
                                 range: NSRange(location: 0, 
                                                length: (string as NSString).length))
        
        // Force layout pass
        textContainer.layoutManager!.glyphRange(for: textContainer)
        textContainer.lineFragmentPadding = 0
        
        let rect = layoutManager.usedRect(for: textContainer)
        
        print(rect)
        
        return NSSize(
            width: bounds.width,
            height: rect.height
        )
    }
    
    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }
}

struct TextView: NSViewRepresentable {
    let text: String
    
    func makeNSView(context: Context) -> NSTextView {
        let view = DWTextView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.textContainerInset = NSSize(width: 0, height: 10)
        view.textContainer!.widthTracksTextView = true
        view.textContainer!.heightTracksTextView = true
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        view.defaultParagraphStyle = style
        view.backgroundColor = NSColor.clear
        view.isEditable = false
        view.string = text
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

struct DefinitionsView: View {
    let definitions: [Definition]
    
    @State
    var showingTruncationInfo = false
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(definitions) {
                    DefinitionView(definition: $0)
                }
            }
            
            if true {
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
                }
            }
                .foregroundColor(.secondary)
                .font(.system(.callout, design: .serif))

            Rectangle().fill(SeparatorShapeStyle())
                .frame(height: 1)
                
            TextView(text: definition.meaning)

            DisclosureGroup("Declensions", isExpanded: $showDeclensions) {
                VStack(alignment: .leading) {
                    Text(definition.possibilities.joined(separator: "\n"))
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .visualEffect(material: .contentBackground)
    }
}


struct DefinitionView_Previews: PreviewProvider {
    static let noun = iWords.Definition(possibilities: ["copi.a               N      1 1 NOM S F                 ", "copi.a               N      1 1 VOC S F                 ", "copi.a               N      1 1 ABL S F                 "], expansion: .noun("copia, copiae", .first, .feminine), meaning: "plenty, abundance, supply; troops (pl.), supplies; forces; resources; wealth; number/amount/quantity; sum/whole amount; means, opportunity; access/admission;")
    
    static let verb = iWords.Definition(
        possibilities: ["consul.ere           V      3 1 PRES ACTIVE  INF 0 X    ", 
                        "consul.ere           V      3 1 PRES PASSIVE IMP 2 S    ",
                        "consul.ere           V      3 1 FUT  PASSIVE IND 2 S    "], 
        expansion: .verb("consulo, consulere, consului, consultus", 
            .third), 
        meaning: "ask information/advice of; consult, take counsel; deliberate/consider; advise; decide upon, adopt; look after/out for (DAT), pay attention to; refer to;*",
        truncated: true)
    
    static var previews: some View {
        Group {
            DefinitionsView(definitions: [noun, verb])
                .frame(width: 500, height: 500, alignment: .center)
        }
    }
}
