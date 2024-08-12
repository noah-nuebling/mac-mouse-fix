
### Why does XCStringsDummyApp exist?

It's to have Xcode export .xcstrings files which we manage manually. 
(At the time of writing, that is just `Markdown.xcstrings) 

When exporting .xcstrings files into an .xcloc file using 
`Product > Export Localizations...` or `xcodebuild -exportLocalizations`,
Xcode will only export .xcstrings files that are members of at least one target.
When we add an .xcstrings file as a member of a target, it will be included in the compiled .app bundle. (I think) 
For some .xcstrings files, we don't to add them to any compiled .app bundles. 
To still have Xcode export those .xcstrings files, we instead add them as a member of the XCStringsDummyApp target. 

### Also see

the `xcode-dummy-target` in the mac-mouse-fix-website repo, which has a very similar purpose. 
There, you'll find more explanations about how and why the DummyTarget was created and set up. 
(You have to disable localization for MainMenu.xib, and manually add an Info.plist file and remove the localizable keys, otherwise those will end up in the .xcloc file) 

### Other

We made this objc for hopefully faster build times.
