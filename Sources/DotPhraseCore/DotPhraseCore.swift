// DotPhraseCore
//
// Minimal, dependency-free phrase loading + search logic for dotphrase.
//
// UI layer should:
// - detect "." + >=1 letter
// - call PhraseStore.search(query)
// - display dropdown
// - on selection: delete typed trigger and insert phrase body
