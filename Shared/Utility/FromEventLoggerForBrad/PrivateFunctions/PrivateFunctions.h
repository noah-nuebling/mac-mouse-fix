//
//  PrivateFunctions.h
//  EventLoggerForBrad
//
//  Created by Noah Nübling on 14.12.24.
//

#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PrivateFunctions : NSObject
@end

typedef enum : int {
    kMFFrameworkHIToolbox,
    kMFFrameworkSkyLight,
} MFFramework;

/// Note: Thought about only writing paths partially and using strstr() over strcmp() – that might improve robustness.
static const char *_Nonnull MFFrameworkToNameMap[] = {
    [kMFFrameworkHIToolbox] = "/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/HIToolbox", /// (As of Dec 2024)
    [kMFFrameworkSkyLight]  = "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight",                                   /// (As of Dec 2024)
};

typedef enum : int {
  kMFSymbolTableSectionAllSections,                     /// Iterate through all symbols.
  kMFSymbolTableSectionLocal,                           /// Symbols that *are not* meant to be linked against from outside the image. But we'll do it anyways <evil laugh>. Might be faster than iterating through all symbols.
  kMFSymbolTableSectionExternallyDefined,               /// Symbols that *are* meant to be linked against from outside the image. Finding these symbols is faster since they are sorted, letting us use bisection.
  kMFSymbolTableSectionUndefinedSymbols,                /// Symbols that are not defined in the image, instead the image imports the definition from another image. (or something like that) Not sure there's any use to searching for these. These symbols are also sorted and fast-to-search-through.
} MFSymbolTableSection;

/// Convenience wrappers for dynamic linker
void *_Nullable MFLoadSymbol_native(MFFramework framework, NSString *nonUnderscoredSymbolName);
void *_Nullable MFLoadSymbol(MFFramework framework, MFSymbolTableSection symtabSection, NSString *symbolName);

/// Custom dynamic linker implementation
void *_Nullable mfdlopen(MFFramework framework);
void *_Nullable mfdlsym(void *mfdlopen_handle, MFSymbolTableSection symtabSection, const char *name);
void mfdlclose(void *mfdlopen_handle);

/// Testing
void do_dynamic_load_benchmarks(void);

NS_ASSUME_NONNULL_END
