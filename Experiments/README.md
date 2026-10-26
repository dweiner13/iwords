# Historical experiments

`LegacyDefinitionTests.swift` and `LegacyTestUtils.swift` preserve tests for the unused experimental parser. They are not part of the test target and their historical Parsing/Difference dependencies are not resolved.

The original `DefinitionParser.swift`, `DefinitionView.swift` and `VisualEffectBackground.swift` remain in the source tree for reference but are excluded from the shipping macOS target. Current tests exercise `DictionaryParser` and the bundled engine instead. Reconsider these prototypes separately before adding any dependencies back.
