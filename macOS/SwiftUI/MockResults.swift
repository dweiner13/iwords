//
//  MockResults.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 7/12/22.
//

import Foundation

let mockResults: [DictionaryController.Result] = [
    .init(input: "viae",
          raw: """
              vi.ae                N      1 1 GEN S F
              vi.ae                N      1 1 LOC S F
              vi.ae                N      1 1 DAT S F
              vi.ae                N      1 1 NOM P F
              vi.ae                N      1 1 VOC P F
              via, viae  N (1st) F
              way, road, street; journey;
              """,
          parsed: [.word(
            DictionaryParser.Result.Word(
                forms: [.init(
                    inflections: ["vi.ae                N      1 1 GEN S F",
                                  "vi.ae                N      1 1 LOC S F"],
                    dictionaryForms: ["via, viae  N (1st) F"])
                ],
                meaning: "way, road, street; journey;"
            )
          )]),
    .init(input: "cum",
          raw: """
              cum                  ADV    POS
              cum  ADV
              when, at the time/on each occasion/in the situation that; after; since/although
              as soon; while, as (well as); whereas, in that, seeing that; on/during which;
              """,
          parsed: [.word(
            DictionaryParser.Result.Word(
                forms: [.init(
                    inflections: ["cum                  ADV    POS"],
                    dictionaryForms: ["cum  ADV  "])
                ],
                meaning: """
                        when, at the time/on each occasion/in the situation that; after; since/although
                        as soon; while, as (well as); whereas, in that, seeing that; on/during which;
                    """
            )
          )])
    ]
