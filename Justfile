# Bare `just` lists recipes.
set default-list := true

# Apply SwiftFormat and SwiftLint autocorrects.
lint:
    swiftformat .
    swiftlint lint .

# Run SwiftLint analyzer rules against a clean build log.
analyze:
    bash scripts/swiftlint-analyze
