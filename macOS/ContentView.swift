//
//  ContentView.swift
//  Shared
//
//  Created by Dan Weiner on 4/10/21.
//

import SwiftUI

struct ContentView: View {
    @State
    private var input: String = "salve mundus"
    @State
    private var results: String = ""
    @State
    private var error: DWError?

    var body: some View {
        VStack {
            HStack {
                TextField("", text: $input)
                Button("Search", action: search)
            }
            TextEditor(text: $results)
                .font(.system(.body, design: .monospaced))
        }
        .padding()
        .frame(width: 500, height: 500)
        .alert(item: $error) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.errorDescription ?? "")
            )
        }
        .onAppear(perform: search)
    }

    private func search() {
        do {
            results = try Dictionary.shared.getDefinition(input, direction: .latinToEnglish) ?? "no results found"
        } catch is DWError {
            self.error = error
        } catch {}
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
