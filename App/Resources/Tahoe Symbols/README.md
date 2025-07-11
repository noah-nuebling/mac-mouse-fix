#  <#Title#>

[Jul 11 2025]
    

[Jun 28 2025]
    
    
    The `AppStoreIcon2` can be extracted from Xcode's IDEStoreKitEditor.ideplugin via "Asset Catalog Tinkerer.app" or "Samra.app" (On macOS Tahoe Beta 2)
        On Image Aligment:
            I set the "Alignment" (margins) in the Asset Catalog so the image has an overall height of 32px at 2x. This makes it look exactly the same as in the Xcode menubar, when I use it in an MMF menu. This kinda makes sense since SFSymbols seem to have a height of 16px in my menus.


Reimport Tests:
    - [Jun 2025] I made custom SFSymbols for switching between spaces, but they weren't displayed at the right size in our NSPopUpButtons.
        To debug this, I exported symbols straight from SFSymbols.app and imported them into Xcode:
            - Exporting menubar.dock.rectangle straight from SFSymbols into Xcode:
                - Using `Export Symbol...`
                    - Export for Xcode 17
                        - .reimport4
                    - Export for Xcode 16
                        - .reimport5
                    - Export for Xcodsfsye 12
                        - .reimport6
                    - Export for Xcode 13
                        - .reimport13
                    - Export for Xcode 14
                        - .reimport14
                    - Export for Xcode 15
                        - .reimport15
                - Using `Export Template...`
                    - Template Setup: Variable:
                        - Compatibility: `SF Symbols 7`:
                            - .reimport7
                        - Compatibility: `SF Symbols 2`:
                            - .reimport8
                        - Compatibility: `SF Symbols 6`:
                            - .reimport9
                    - Template Setup: Static:
                        - Compatibility `SF Symbols 7`:
                            - .reimport10
                                
            - Teststststst
                - .reimport
                    -> Perfect size
                - .reimport2
                    -> One px too narrow
                - .reimport3
                    -> One px too narrow
                - .reimport4
                    -> One px too narrow
                - .reimport5
                    -> One px too narrow
                - .reimport6
                    -> Perfect size
                - .reimport8
                    -> One px too narrow
                - .reimport7
                    -> One px too narrow
                - .reimport9
                    -> One px too narrow
                - .reimport13
                    -> Perfect size (!)
                - .reimport14
                    -> Perfect size
                - .reimport15
                    -> One px too narrow (!)
                
            Summary:
                Using `Export Template...`, the symbol is one px too narrow, in any case 
                Using `Export Symbol...`,   the symbol is one px too narrow, when picking Xcode 15, 16, or 17
                
                    
        - Other findings
            - I found I can make the custom SFSymbol appear at the right size by scaling it such that the height of its alignment rect is exactly 8. (For normal images, I was setting their height to 16 instead). 
                I have no clue what's going on
            - [Jun 30 2025] Actually, the custom symbols which we managed to make look pixel-perfect on Tahoe were slightly off on Sequoia I think. – But we don't plan on displaying those symbols on Sequoia.
        
        - Other Notes:
            - [Jun 30 2025] The pixel-perfect custom symbols we made as of now are `mf.menubar.arrow.left.rectangle.v2`, `mf.menubar.arrow.right.rectangle.v2` and `mf.menubar.arrow.left.and.right.rectangle.v2` 


Summary / Tips / Takeaways
    - To make custom SFSymbol:
        - Go to SFSymbols.app, pick `Export Symbol...` with "Export for Xcode 14" (newer versions mess up pixel alignment [Jun 2025])
        - Edit in Sketch
        - Import into SFSymbols.app to validate (Xcode just silently returns nil [Jun 2025])
        - Import into Xcode
        - Load using our `+[Symbols imageWithSymbolName:]` API
    - Other learnings:
        - Don't rasterize the loaded symbol (e.g. using `coolTintedImage:`) – that messes up the sizing. I think the sizing is stored in the private NSSymbolImageRep.
    
