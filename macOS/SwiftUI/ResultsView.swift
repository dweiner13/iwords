//
//  ResultsView.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 7/12/22.
//

import SwiftUI

struct ResultsView: View {
    let results: [DictionaryController.Result]

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(results) { result in
                VStack(alignment: .leading) {
                    Text(verbatim: result.input)
                        .bold()
                    Text(verbatim: result.raw ?? "no raw results to show")
                }
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 10)
            }
        }
    }
}

struct ResultsView_Previews: PreviewProvider {
    static var previews: some View {
        ResultsView(results: mockResults)
            .frame(width: 500, height: 500)
    }
}
