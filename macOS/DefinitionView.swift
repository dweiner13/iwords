//
//  DefinitionView.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 4/24/21.
//

import SwiftUI
import DWUtils

// MARK: DefinitionsView

@available(macOS 11.0, *)
struct DefinitionsView: View {
    let definitions: ([ResultItem], Bool)
    
    @State
    var showingTruncationInfo = false
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(definitions.0) {
                    switch $0 {
                    case .definition(let definition):
                        DefinitionView(definition: definition)
                    case .text(let text):
                        Text(verbatim: text)
                            .safeSelectable()
                            .font(.system(size: 16,
                                          weight: .regular,
                                          design: .serif))
                            .padding(.leading, 16)
                    }
                }
            }
            .padding(.vertical, 16)
            
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

// MARK: DefinitionView
@available(macOS 11.0, *)
struct DefinitionView: View {
    let definition: Definition

    @State
    var showDeclensions = false

    func expansionDescription(_ exp: Expansion) -> String {
        var descr = exp.pos.description
        switch exp {
        case .noun(_, let declension, let gender, _):
            if let declension = declension {
                descr +=  ", \(declension.description)"
            }
            descr += ", \(gender.description)"
        case .verb(_, let conjugation, _):
            if let conjugation = conjugation {
                descr += ", \(conjugation)"
            }
        case .adj, .adv, .pron, .conj:
            break
        case .prep(_, let `case`, _):
            if let `case` = `case` {
                descr += ", \(`case`.description)"
            }
        case .vpar(_, let conj, _):
            if let conj = conj {
                descr += ", \(conj.description)"
            }
        }
        if !exp.notes.isEmpty {
            descr += " ("
            descr += exp.notes.joined(separator: ", ")
            descr += ")"
        }
        return descr
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            if !definition.possibilities.isEmpty {
                VStack(alignment: .leading) {
                    ForEach(definition.possibilities, id: \.debugDescription) { possibility in
                        SafeSelectableText {
                            Text(possibility.word)
                                .foregroundColor(Color.primary)
                                .font(.system(size: 16, weight: .regular, design: .serif))
                            + Text("  ")
                            + Text(verbatim: possibility.description)
                                .foregroundColor(.secondary)
                                .font(.system(size: 16, weight: .regular, design: .serif))
                        }
                    }
                    .multilineTextAlignment(.leading)
                }.padding(.top, 16)

                Divider()
            }

            ForEach(definition.words, id: \.meaning) { word in
                VStack(alignment: .leading, spacing: 4) {
                    if let expansion = word.expansion {
                        HStack(alignment: .firstTextBaseline) {
                            SafeSelectableText {
                                Text(verbatim: expansion.principleParts ?? "")
                                    .font(.system(size: 16, weight: .bold, design: .serif))
                                + Text("  ") + Text(verbatim: expansionDescription(expansion))
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16, weight: .regular, design: .serif))
                            }
                        }
                        .padding(.leading, 16)
                    }

                    Text(verbatim: word.meaning)
                        .safeSelectable()
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .padding(.leading, 32)
                }
            }
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
    static let result = parse(previewQuery("queries/virimus"))!
    
    static var previews: some View {
        Group {
            DefinitionsView(definitions: (result.0, result.1))
//            DWBridgedDefinitionView(definitions: [noun, verb])
                .padding(.vertical)
                .frame(width: 500, height: 900, alignment: .center)
        }
    }
}
