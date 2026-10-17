# Bare `just` lists recipes.
set default-list := true

# SwiftFormat and SwiftLint autocorrect.
lint:
	swiftformat .
	swiftlint lint --fix
