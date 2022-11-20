#  On Bundle Size

- macOS 10.14.4 is the earliest version with Swift ABI stability. Setting deployment target to that greatly shrinks bundle size (more than half)
- All the SFSymbol fallbacks for pre-Bug Sur only account for a few KB, so we'll leave them
- When archiving, the bundleSize is much smaller than just building release normally. Probably because of debug symbols being stripped or sth.
- If we can somehow reuse the SPM libs between mainApp and helper we should be able to shave off another 5 mb or so (currently at 15 mb) 
