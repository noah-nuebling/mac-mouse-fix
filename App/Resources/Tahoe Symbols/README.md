# Tahoe Symbols Readme


How we found `AppStoreIcon2`:
    The `AppStoreIcon2` can be extracted from Xcode's IDEStoreKitEditor.ideplugin via "Asset Catalog Tinkerer.app" or "Samra.app" (On macOS Tahoe Beta 2)
        On Image Aligment:
            I set the "Alignment" (margins) in the Asset Catalog so the image has an overall height of 32px at 2x. This makes it look exactly the same as in the Xcode menubar, when I use it in an MMF menu. This kinda makes sense since SFSymbols seem to have a height of 16px in my menus.

Making your own custom SF Symbols: [Jul 2025]
    - To make custom SFSymbol:
        - Go to SFSymbols.app, pick `Export Symbol...` with "Export for Xcode 14" (newer versions mess up pixel alignment [Jun 2025])
        - Edit in Sketch
        - Import into SFSymbols.app to validate (Xcode just silently returns nil [Jun 2025])
        - Import into Xcode
        - Load using our `+[Symbols imageWithSymbolName:]` API
    - Other learnings:
        - Don't rasterize the loaded symbol (e.g. using `coolTintedImage:`) – that messes up the sizing. I think the sizing is stored in the private NSSymbolImageRep.
    - Also see: 
        - Tahoe Symbols/README.md in commit fd3fb116094e10fff21da51f73ba992c5d1e6003 which contains 
            - Detailed test notes regarding SF Symbols.app export issues
            - Other findings
            -> (In the next commit we deleted that stuff)
        - Apple Feedback FB18759197 "Symbols exported from SF Symbols app render incorrectly when imported to Xcode"
    - I created 3 custom symbols to signify space-switching actions: [Jul 2025]
        `mf.menubar.arrow.left.rectangle.v2`, `mf.menubar.arrow.right.rectangle.v2` and `mf.menubar.arrow.left.and.right.rectangle.v2`
        
    
