# Bare `just` lists recipes.
set default-list := true

# Apply SwiftFormat and SwiftLint autocorrects.
lint:
    swiftformat .
    swiftlint lint .
