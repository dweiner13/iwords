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
            LazyVStack(alignment: .leading, spacing: 16) {
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

            if !definition.possibilities.isEmpty {
                VStack(alignment: .leading) {
                    ForEach(definition.possibilities, id: \.debugDescription) { possibility in
                        SelectableText {
                            Text(possibility.word)
                                .foregroundColor(Color.primary)
                                .font(.system(size: fontSizeController.fontSize * 1, weight: .regular, design: .serif))
                            + Text("  ")
                            + Text(verbatim: possibility.description)
                                .foregroundColor(.secondary)
                                .font(.system(size: fontSizeController.fontSize * 1, weight: .regular, design: .serif))
                        }
                    }
                    .multilineTextAlignment(.leading)
                }.padding(.top, 16)

                Divider()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    SelectableText {
                        Text(verbatim: definition.expansion.principleParts)
                            .font(.system(size: fontSizeController.fontSize * 1, weight: .bold, design: .serif))
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
                        .font(.system(size: fontSizeController.fontSize * 1, weight: .regular, design: .serif))
                    }
                }
                .padding(.leading, 16)

                Text(verbatim: definition.meaning)
                    .safeSelectable()
                    .font(.system(size: fontSizeController.fontSize, weight: .regular, design: .serif))
                    .padding(.leading, 32)
            }
            .padding(.leading, 0)
        }
        .padding(.horizontal)
    }
}

func previewQuery(_ name: String) -> String {
    String(data: NSDataAsset(name: name)!.data, encoding: .utf8)!
}

// MARK: DefinitionView_Previews
@available(macOS 11.0, *)
struct DefinitionView_Previews: PreviewProvider {
    static let definitions = parse(previewQuery("queries/incubat alias res vici"))!
    
    static var previews: some View {
        Group {
            DefinitionsView(definitions: definitions)
//            DWBridgedDefinitionView(definitions: [noun, verb])
                .environmentObject(FontSizeController())
                .padding(.vertical)
                .frame(width: 500, height: 900, alignment: .center)
        }
    }
}
