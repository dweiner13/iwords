//
//  ContentView.swift
//  iWords2
//
//  Created by Dan Weiner on 7/12/22.
//

import SwiftUI

class LookupModel: ObservableObject {
    @Published
    var searchText: String = ""

    let dictionaryController: DictionaryController = .init(direction: .latinToEnglish)

    @Published
    var results: [DictionaryController.Result]?

    init(results: [DictionaryController.Result]?) {
        self.results = results
    }

    convenience init() {
        self.init(results: nil)
    }

    func search() {
        dictionaryController.search(text: searchText) { result in
            switch result {
            case .failure(let error):
                break
            case .success(let results):
                self.results = results
            }
        }
    }
}

struct ContentView: View {
    @StateObject
    var lookupModel: LookupModel

    init(results: [DictionaryController.Result]?) {
        self._lookupModel = .init(wrappedValue: LookupModel(results: results))
    }

    init() {
        self.init(results: nil)
    }

    var body: some View {
        NavigationSplitView {
            Text("Sidebar")
        } detail: {
            VStack {
                HStack {
                    TextField(text: $lookupModel.searchText) {
                        Text("Search")
                    }
                    .onSubmit {
                        lookupModel.search()
                    }
                    .textFieldStyle(.roundedBorder)
                    Button("Go") {
                        lookupModel.search()
                    }
                    .border(Color.accentColor, width: 2)
                }
                .padding([.leading, .trailing, .top], 6)
                Group {
                    ScrollView {
                        HStack {
                            if let results = lookupModel.results {
                                ResultsView(results: results)
                                    .padding()
                            } else {
                                Text("No results")
                            }
                            Spacer()
                        }
                    }
                }.background(Color.white)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(results: mockResults)
            .frame(width: 700, height: 600)
    }
}
