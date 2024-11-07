#  On Bundle Size & Deployment Target

- macOS 10.14.4 is the earliest version with Swift ABI stability. Setting deployment target to that greatly shrinks bundle size (more than half)
    - Update: (04.10.2024) We now set the deployment target to 10.15 to be able to use Swift concurrency stuff (Task and async/await).
        -> I think this is useful to clean up the License.swift code since it uses pretty deeply nested asynchronous completion handlers.
        -> Alternatively we could perhaps use alibaba/coobjc which adds async/await to objc and older macOS versions, but it seems to be under no/minimal maintenance based on https://github.com/alibaba/coobjc/issues/105#issuecomment-803732973
- All the SFSymbol fallbacks for pre-Bug Sur only account for a few KB, so we'll leave them
- When archiving, the bundleSize is much smaller than just building release normally. Probably because of debug symbols being stripped or sth.
- If we can somehow reuse the SPM libs between mainApp and helper we should be able to shave off another 5 mb or so (currently at 15 mb) 
