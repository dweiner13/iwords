//
//  DefinitionView.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 4/24/21.
//

import SwiftUI

// MARK: DefinitionsView

@available(macOS 11.0, *)
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
        .visualEffect(material: .contentBackground)
    }
}

@available(macOS 11.0, *)
struct SelectableText: View {
    let content: () -> Text

    var body: some View {
        if #available(macOS 12.0, *) {
            content().textSelection(.enabled)
        } else {
            content()
        }
    }
}

@available(macOS 11.0, *)
extension Text {
    func safeSelectable() -> some View {
        SelectableText { self }
    }
}

// MARK: DefinitionView
@available(macOS 11.0, *)
struct DefinitionView: View {
    let definition: Definition

    @State
    var showDeclensions = false

    @EnvironmentObject
    var fontSizeController: FontSizeController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                SelectableText {
                    Text(verbatim: definition.expansion.principleParts)
                        .font(.system(size: fontSizeController.fontSize * 1.3, weight: .medium, design: .serif))
                    + Text("  ") + { () -> Text in
                        switch definition.expansion {
                        case .noun(_, let declension, let gender):
                            return Text("\(definition.expansion.pos.description), \(declension.description), \(gender.description)")
                        case .verb(_, let conjugation):
                            return Text("\(definition.expansion.pos.description)\(conjugation.map { ", " + $0.description } ?? "")")
                        case .adj, .adv:
                            return Text("\(definition.expansion.pos.description)")
                        }
                    }()
                    .foregroundColor(.secondary)
                    .font(.system(size: fontSizeController.fontSize * 1.1, weight: .regular, design: .serif))
                }
            }

            VStack(alignment: .leading) {
                ForEach(definition.possibilities, id: \.debugDescription) { possibility in
                    SelectableText {
                        Text(possibility.word)
                            .foregroundColor(Color.primary)
                            .font(.system(size: fontSizeController.fontSize * 0.9, weight: .medium, design: .monospaced))
                        + Text("  ")
                        + Text(verbatim: possibility.description)
                            .foregroundColor(.secondary)
                            .font(.system(size: fontSizeController.fontSize * 0.9, weight: .regular, design: .serif))
                    }
                }
                .multilineTextAlignment(.leading)
            }

            Rectangle()
                .fill(SeparatorShapeStyle())
                .frame(height: 1)

            Text(verbatim: definition.meaning)
                .safeSelectable()
                .font(.system(size: fontSizeController.fontSize, weight: .regular, design: .serif))
        }
        .padding()
    }
}

// MARK: DefinitionView_Previews
@available(macOS 11.0, *)
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
