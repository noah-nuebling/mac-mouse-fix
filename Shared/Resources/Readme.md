#  Notes on Assets & Resources

**On shareed assets** 
  We moved all .xcassets catalogs into the `Shared` folder, (9. August 2024) even when they are not used by both the MainApp, and the Helper bundle, so that we 
  can keep an overview. 
  But also, we *should* be sharing all resources, since the MainApp and Helper can access each others bundles at runtime. Right now we're duplicating some resources which
  is wasteful.

**On Westfalia Font:** 
  The Westfalia font is the font for the original "Buy me a milkshake! :)" button. Under MMF 2 we created the button in a graphics program and simply imported the image into Xcode, 
  but MMF 3 is localizable so we can't have images containing text. We are shipping the Westfalia font with MMF 3 because we meant to build the milkshake button in code so that it is 
  localizable, but then we transformed the milkshake button into a simple link using the system font, and so we are *not* using the westfalia font at the time of writing.

**On shipping fonts with a Mac App**
  Guide: https://troz.net/post/2020/custom-fonts/
  > This teaches us to add an "Application fonts resources path" Info.plist key. We used to do this for the Westphalia font iirc. 
    For registering the CoolSFSymbols.otf font (which allows us to display SFSymbols in tooltips) we use the `CTFontManager` API to register the font on a system level. 
    I haven't actually tested whether the simpler and cleaner Info.plist strategy would work there as well.  
    TODO: Test that. 
    More info inside CoolSFSymbolsFont.m.

**On shipping SFSymbols as images inside Asset Catalogs**

  This might be unnecessary, but the MainAppSFSymbols.xcassets folder takes up 101 KB in the source code at the time of writing. (9. August 2024) (Might even be compressed when compiled) 
  -> So it's not a priority to remove it. 
  I think the reason we added it was probably to support displaying the Symbols on pre-BigSur macOS versions 
  (SF Symbols were introduced with macOS 11 Big Sur) But since we've officially dropped support for pre-Big Sur versions, we can consider removing 
  the SF Symbols from our Assets. Arguments to consider are:
  1. Some SF Symbols we're using might have been introduced after Big Sur, so we'd have to spend time to make sure nothing we're removing is needed on Big Sur.
  2. We are still *un*offically support pre-Big Sur versions, which some people are really 
    happy about. On the other hand, the UI doesn't look correct for them anyways, and e.g. the tabBar buttons don't display SF Symbols anyways pre-BigSur iirc, 
    because I couldn't get it to look ok, so therefore it wouldn't be too bad for pre-Big Sur users to remove the SF Symbols I think, since the UI is broken 
    and unpolished anyways. But then again, the symbols only take up a few dozen KB, so I'll just leave them for now.
