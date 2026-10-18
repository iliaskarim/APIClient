# Bare `just` lists recipes.
set default-list := true

# Apply SwiftFormat fixes, then run SwiftLint.
lint:
    swiftformat .
    swiftlint lint .

# Run SwiftLint analyzer rules against a clean build log.
analyze:
    bash scripts/swiftlint-analyze

# Run unit tests with coverage and write an HTML report to coverage/.
test:
    bash scripts/coverage
