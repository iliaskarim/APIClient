# Bare `just` lists recipes.
set default-list := true

# Apply SwiftFormat fixes, then run SwiftLint.
lint:
    swiftformat .
    swiftlint lint .

# Run SwiftLint analyzer rules against a clean build log.
analyze:
    bash scripts/swiftlint-analyze
