//
//  PrivateFunctions.m
//  EventLoggerForBrad
//
//  Created by Noah Nübling on 14.12.24.
//

#import "PrivateFunctions.h"

#import "SharedUtility.h"
#import "Logging.h"

#import "MFBenchmark.h"
#import "ListOperations.h"

/// Import all the weird mach-o and dyld stuff

#import <dlfcn.h>
#import <mach-o/nlist.h>
#import <mach-o/dyld.h>

#if 0
#import <mach-o/dyld_images.h>
#import <mach-o/loader.h>
#import <mach-o/stab.h>
#endif

#if 0
#import <nlist.h> /// Conflicts with <mach-o/nlist.h>. Not sure what the difference is.
#import <stab.h>
#endif

#if 0
#import <mach-o/reloc.h>
#import <mach-o/utils.h>
#import <mach-o/ldsyms.h>
#endif

/// --------------------
/// How to find private function symbols
/// --------------------
/// Here are the techniques I can think of:
/// - Use lldb to step into functions and see the underlying private functions they call.
/// - Inspect the symbol table
///     - Easiest way: `(lldb) image dump symtab <Framework/Image>`
///     - Additional info can be obtained using `nm` and `symbols` command-line-tools with various options.
///         -> if you wanna examine System libraries using `nm` – first extract them from the shared cache using `dyld-shared-cache-extractor`
///     - Use RuntimeBrowser.app (shows objc classes and methods, not C functions.)
/// - Use `(lldb) breakpoint set <FunctionName>` to examine the function at runtime - this should help to figure out what the arguments and return-type are.
///
/// --------------------
/// How to call private functions
/// --------------------
/// Once you found an interesting private function you need to *link* against it so you can call it.
/// I think the nicest way to do this is using the C `extern` keyword.
///     > You might have to explicitly add the function's Framework to your Xcode target, so the linker can find the symbol and link it to your 'extern' declaration.
///
///     Update: It seems you don't even need the `extern` keyword to import undocumented functions! ChatGPT says it's because function declarations have `external` linkage by default.
///
/// Alternatives:       (Dynamic linking)
///     - `dlopen()`/`dlsym()`/`dlclose()`
///         dlopen() and dlsym() let you load binaries and link their symbols at runtime. I think there's **never a reason** to use this over `extern` except if the presence of the desired symbols in your program is optional (e.g. if you have a plugin system.)
///     - `mfdlopen()`/`mfdlsym()`/`mfdlclose()`
///         Custom reimplementation of dlopen()/dlsym()
///         Benefit over dlopen()/dlsym(): Lets you load symbols from the **local** section of a framework's symbol table (more on symbol-table-sections below).
///         Local symbols are supposed to be hidden from linkers but our custom implementation can find them anyways!
///             -> This way you should be able to link against any symbol in a binary – that is all the symbols which `(lldb) image dump symtab <Framework/Image>` shows you.
///
/// ------------------------
/// Concepts around symbol and function visibility:
/// -------------------------
/// **private** functions
///     I call any framework/library function that is not exposed in an easy-to-import .h file 'private'.
///     Maybe a better term would be 'undocumented' or 'unexposed'.
///     These undocumented functions might still be public or **external** from the perspective of the framework's / library's mach-o binary – and therefore – easy-to-import when you know the function's `symbol` string.
///
/// **external** during C compilation.
///     Afaik 'external' in C generally means that a symbol is visible outside its C compilation unit during the linking that happens **while a binary is compiled**.
///     -> So in this context, an 'external' symbol is one that is visible to other compilation units during compilation
///
///     Notes:
///         - IIRC, you can turn off this external linking with `static`.
///
/// **external** in a compiled mach-o binary
///     In an Apple mach-o binary (which is the output of a compiler) an *external* symbol is one that can be linked against by *other binaries*.
///
///     Inside the mach-o binary's **symbol-table there are 3 sections**:
///         **local** section:                           Symbols which are not meant to be seen by linkers/other binaries. Intended for debugging purposes. `local` symbols can be removed using the `strip` clt. (Source: `struct dysymtab_command` docs )
///         **externally defined** section:     Symbols which are meant to be found by the linker and which *have a definition* in the binary. Other binaries can find and import this definition. -> In other words: **exported symbols**
///         **undefined** section:                  Symbols which are meant to be found by the linker and which *don't have a definition* in the binary. The definition is meant to be found and imported from the exported symbols of another binary. -> In other words: **imported symbols**
///
///         Notes:
///             - The table sections are specified by the `struct dysymtab_command` load command of the binary.
///             - **local** symbols are not meant to be found by linkers but our custom `mfdlsym()` linker can still find them by parsing the symbol table directly!
///             - If a symbol is in the **externally defined** or **undefined** section, aka meant to be found by a linker, then the `nm` clt tags it with **external**, otherwise with **non-external**.
///
///     Sidenotes about `nm`
///         - Use `nm -p -m` to dump the symbol table of an executable.
///             - To analyze a macOS Framework with `nm`, first use `dyld-shared-cache-extractor` (Frameworks are consolidated into a 'shared cache' in newer macOS versions.)
///         - `nm` and `(lldb) immage dump symtab` will show the symbol table in native order, letting us see the 3 table sections (while the `symbols` clt always reorders the table somehow.)
///
/// **private external**
///     Now we understand the 2 meanings of `external`:
///         During C compilation, `external` symbols can be linked by other compilation units, while in a compiled binary, `external` symbols can be linked by other binaries.
///
///     A **private external** symbol is something in-between: A symbol which is visible to other compilation units during compilation, but which is hidden from other binaries after compilation has completed.
///
///     Notes:
///         - Private external symbols end up in the **local** section of the symbol table – thereby they are hidden from other binaries.
///         - In the `nm` clt, private external symbols are marked with `non-external (was a private external)`
///         - Use the `symbols --noDemanling` clt to see which symbols have the `PEXT` flag (PEXT standing for private external)
///             Sidenote: There's also an `EXT` tag - I'm not totally sure what that means.
///         - In code, parse `nlist_64.n_type` to see if a symbol has the `N_PEXT` flag. (The `nlist_64` struct is a symbol table entry.)
///         - Here's a private-external explanation from LLVM forums: https://discourse.llvm.org/t/private-extern-what-is-that/11621
///             (Extremely tangential sidenote: Found this using yandex, Google and DDG results were kinda useless, ecosia also better)
///             Other takeaways from the forum dicussion:
///             - "Private external" is an Apple extension and doesn't exist on other platforms.
///             - In C code, using `__private_extern__` or `__attribute__((visibility("hidden")))` makes  symbol private external
///
/// **externally visible**:
///     In lldb's `image dump symtab`"externally visible"  symbols are marked with `   X `
///
///     (From looking at HIToolbox) Most of the `   X ` aka externally visible symbols are found in the **externally defined** section of the symbol table.
///         but some (not all) symbols in the **undefined** section of the symtab are also also marked with `   X ` aka externally visible.
///         -> I don't understand this concept
///         -> (Perhaps this X describes the same property as the `N_EXT` flag present on some symtab entries?)
///
/// ----------------
/// Other interesting stuff
/// ---------------
/// - Apple's dlopen()/dlsym() source code: https://github.com/opensource-apple/dyld/blob/master/src/dyldAPIs.cpp
///         (Or perhaps this is the latest source code? - apple-oss-distributions is the 'official' repo I think: https://github.com/apple-oss-distributions/dyld/blob/main/dyld/DyldAPIs.cpp)

@implementation PrivateFunctions

void *_Nullable MFLoadSymbol_native(MFFramework framework, NSString *nonUnderscoredSymbolName) {
        
    /// Convenience wrapper around dlopen(), dlsym(), dlclose()
    ///
    /// Speed:      Our custom `MFLoadSymbol()` was a bit fast in my testing (Dec 2024) - probably use that instead.
    /// Caution:    The symbolName arg shouldn't be prefixed with underscore (like it should be for `MFLoadSymbol()`) – dlsym adds the prefix internally. – See its src code: https://github.com/opensource-apple/dyld/blob/3f928f32597888c5eac6003b9199d972d49857b5/src/dyldAPIs.cpp#L1669
    
    /// NULL-safety
    if (!nonUnderscoredSymbolName || nonUnderscoredSymbolName.length == 0) return NULL;
    
    /// Get framework path.
    const char *targetframeworkName = safeindex(MFFrameworkToNameMap, arrcount(MFFrameworkToNameMap), framework, NULL);
    if (!targetframeworkName) return NULL;
    
    /// Clear existing errors
    dlerror();
    
    /// Use dlopen
    void *handle = dlopen(targetframeworkName,
                          RTLD_LAZY/*RTLD_NOW*/     | /** Docs say this makes things faster - prevents "all external function refs" in the image to be loaded at once. Not sure what that means. */
                          RTLD_LOCAL/*RTLD_GLOBAL*/ | /** Don't make the image available in a 'global' context. Don't understand this. Feels like this would be faster? Not sure. */
                          0/*RTLD_NOLOAD*/          | /** Do nothing if image is not loaded, yet. See no good reason for using that. */
                          RTLD_NODELETE             | /** Don't unload the image upon dlclose(). See `dlclose()` comments below. */
                          RTLD_FIRST                | /** -> dlsym(handle, ...) will only search the specified image – not subsequent ones. Not sure why we would want that. Feels like it should make things faster. */
                          0);
                          
    if (!handle) {
        DDLogError(@"dlopen failed with error: %s", dlerror());
        return NULL;
    }
    
    /// Schedule dlclose
    ///     Might cause the image to be umapped, causing the `result` symbol-pointer to become invalid.
    ///     > But I think `RTLD_NODELETE` prevents that.
    ///     > See discussion in `mfdlclose()`.
    mfdefer ^{
        if (handle) {
            int rt = dlclose(handle);
            if (rt != 0) { DDLogError(@"dlclose failed with error: %s", dlerror()); }
        }
    };
    
    /// Use dlsym
    void *result = dlsym(handle, [nonUnderscoredSymbolName cStringUsingEncoding:NSUTF8StringEncoding]);
    if (!result) {
        DDLogError(@"dlsym failed to get symbol %@ from framework: %s with error: %s", nonUnderscoredSymbolName, targetframeworkName, dlerror());
    }
    
    /// Return
    return result;
}

void *_Nullable MFLoadSymbol(MFFramework framework, MFSymbolTableSection symtabSection, NSString *symbolName) {
    
    /// Convenience wrapper around `mfdlopen()` and `mfdlsym()`
    ///
    /// On caching
    ///     We used to have an NSDictionary cache here.
    ///         > But we decided not to cache here – just avoid calling this function multiple times for the same symbol and instead save the symbol address.
    ///         Findings from the NSDictionary-cache experiment:
    ///             - Cache seemed to speed things up in most cases.
    ///             - The dyld functions seem to speed up after the first time calling them (even without the explicit NSDictionary cache)
    ///
    /// On thread safety
    ///     How Apple handles it:
    ///         dlopen() uses some dl-framework-internal locks to prevent images from being unloaded (and/or loaded and/or modified) while dlopen() runs (I think)
    ///         dlsym() uses a refcounted handle from dlopen(). The refcount should make sure the image is not unloaded while dlsym() runs.
    ///             Loaded images are never modified (I think) so preventing unloading during dlsym() should be sufficient to avoid race-conditions (no need for locks)
    ///         -> Source: My superficial understanding of Apple's dlopen/dlsym source code found in `dyldAPIs.cpp` – it's linked above [as of Dec 2024]
    ///     How we handle it:       [as of Dec 2024]
    ///         mfdlopen() uses dlopen() under-the-hood so it should have the same characteristics regarding thread-safety.
    ///         mfdlsym() does not use `dlsym()` but it should benefit from the refcounted `dlopen()` handle in the same way.
    
    /// Null-safety
    if (!symbolName || symbolName.length == 0) return NULL; /// Note: We don't log errors here because all the underlying functions already do.
    
    /// Open image
    void *header = mfdlopen(framework);
    if (!header) return NULL;
    
    /// Find symbol
    void *result = mfdlsym(header, symtabSection, [symbolName cStringUsingEncoding:NSUTF8StringEncoding]);
    if (!result) return NULL;
    
    /// Don't close image
    ///     Note: We're not using `mfdlclose()` so that the image definitely doesn't get unmapped – unmapping might render the `result` symbol-address invalid I think. Learn more at `mfdlclose()`
    
    /// Return
    return result;
    
}

void *_Nullable mfdlsym(void *mfdlopen_handle, MFSymbolTableSection symtabSection, const char *name) {
    
    /// Custom dynamic linker implementation.
    ///     Alternative to dlsym()
    ///     Main reason to use this over `dlsym()` is that it can find symbols from the `local` section of the symbol table.
    /// Speed:
    ///     In my testing this is more than 2x faster than Apple's `mfdlsym()`!
    /// Alternative implementations:
    ///     The existence of the`MH_NLIST_OUTOFSYNC_WITH_DYLDINFO` constant suggests that there are alternate ways to access a list of symbols (We're using nlist as of Dec 2024)
    /// Based on
    ///     csbypass: https://github.com/kpwn/935csbypass/blob/f61333d69efa38a4607d80933b9cf168b330935b/cs_bypass.m#L87
    
    /// Guard: non-empty symbol name
    if (!name || strlen(name) == 0) {
        mfassert(false, @"symbol name is empty.");
        return NULL;
    }
    /// Guard: non-null handle
    if (!mfdlopen_handle) {
        mfassert(false, @"mfdlopen() handle is NULL.");
        return NULL;
    }
    /// Get the `mach_header` for the mfdlopen handle
    ///     Using neat undocumented func `_dyld_get_dlopen_image_header()`
    ///     > Source code here: https://github.com/apple-oss-distributions/dyld/blob/66c652a1f1f6b7b5266b8bbfd51cb0965d67cc44/dyld/DyldAPIs.cpp#L164
    extern const struct mach_header *_dyld_get_dlopen_image_header(void *dlopen_handle);
    const struct mach_header *mh_ = _dyld_get_dlopen_image_header(mfdlopen_handle);
    
    /// Guard: non-null mach header
    if (!mh_) {
        mfassert(false, @"mach header is NULL");
        return NULL;
    }
    /// Validate mach header magic
    if (mh_->magic != MH_MAGIC_64) { /// If ->magic is `MH_MAGIC` this is a 32 bit header, if it's `MH_CIGAM_64`, the binary was created with the "opposite byte alignment" of the current machine (Src: https://quadratic.xyz/posts/understanding-mach-o-header/)
        mfassert(false, @"expected the mach headers 'magic' to be %x, but found: %x", MH_MAGIC_64, mh_->magic);
        return NULL;
    }
    /// Cast to 64 bit
    const struct mach_header_64 *mh = (void *)mh_;
    
    /// Tell people to use `extern`
    if ((false) && symtabSection != kMFSymbolTableSectionLocal) {
        DDLogWarn(@"mfdlsym: The symtabSection for %s is not `local`."
                  "\nIf the symbol is really not in the local section, you could probably link by using C's extern keyword instead of doing it at runtime."
                  "\n(When using extern with a symbol in a PrivateFramework, you might have to add that framework to your Xcode target for the linker to find the symbol.)",
                  name);
    }
    
    /// Define `symbol` validation
    ///     This is just a sanity check to test our understanding and should be not be called in release builds.
    void (^validateSymbol)(const struct nlist_64 *, MFSymbolTableSection) = ^(const struct nlist_64 *symtab_entry, MFSymbolTableSection symtabSection) {
        #define hasPEXT           ((symtab_entry->n_type & N_PEXT)     != 0)
        #define hasEXT            ((symtab_entry->n_type & N_EXT)      != 0)
        #define hasUndefined      ((symtab_entry->n_type & N_TYPE) == N_UNDF)       /** No clue what I'm doing. */
        #define hasWeak           ((symtab_entry->n_desc & N_WEAK_REF) != 0)        /** No clue what this does, but nm shows `weak external` for some symbols */
        if (symtabSection == kMFSymbolTableSectionLocal) {
            mfassert(1        && !hasEXT  && !hasUndefined    && !hasWeak     && "mfdlsym: Weird flags");
        }
        if (symtabSection == kMFSymbolTableSectionExternallyDefined) {
            mfassert(!hasPEXT && hasEXT   && !hasUndefined    && !hasWeak     && "mfdlsym: Weird flags");
        }
        if (symtabSection == kMFSymbolTableSectionUndefinedSymbols) {
            mfassert(!hasPEXT && hasEXT   && hasUndefined     && 1            && "mfdlsym: Weird flags.");
        }
        #undef hasPEXT
        #undef hasEXT
        #undef hasUndefined
        #undef hasWeak
    };
    
    /// Get load commands
    bool (^conditions[])(struct load_command *lc) = {
        /*0*/^bool (struct load_command *lc) { return lc->cmd == LC_SYMTAB; },
        /*1*/^bool (struct load_command *lc) { return lc->cmd == LC_SEGMENT_64; },
        /*2*/^bool (struct load_command *lc)
        {
            if (lc->cmd != LC_SEGMENT_64) return false;
            struct segment_command_64 *s = (void *)lc;
            return 0 == strcmp(s->segname, SEG_LINKEDIT);
        },
        /*3*/(symtabSection == kMFSymbolTableSectionAllSections) ? /// We can only use the `LC_DYSYMTAB` info to optimize in case we're searching in a specific symtab section (I think)
            NULL :
            ^bool (struct load_command *lc) { return lc->cmd == LC_DYSYMTAB; },
    };
    struct load_command *lcs[arrcount(conditions)];
    find_load_commands(mh, conditions, arrcount(conditions), lcs);
    struct symtab_command       *lc_symtab           = (void *)lcs[0];
    struct segment_command_64   *lc_first_segment    = (void *)lcs[1];
    struct segment_command_64   *lc_linkedit_segment = (void *)lcs[2];
    struct dysymtab_command     *lc_dysymtab         = (void *)lcs[3];
    
    /// Guard: loadCommands != NULL
    if (!lc_symtab || !lc_first_segment || !lc_linkedit_segment) {
        mfassert(false, @"A required loadCommand is unexpectedly NULL: symtab: %p, first_segment: %p, linkedit_segment: %p", lc_symtab, lc_first_segment, lc_linkedit_segment);
        return NULL;
    }
    if (!lc_dysymtab && symtabSection != kMFSymbolTableSectionAllSections) {
        mfassert(false, @"The dysymtab load-command is NULL, but the symtabSection is not 'allSections', so we need that load-command to tell us where the sections are. symtabSection is %lu", (unsigned long)symtabSection);
        return NULL;
    }
    /// Calculate slide
    ///     Notes:
    ///         - You can also get the slide through `_dyld_get_image_vmaddr_slide(frameworkIndex)`
    ///         - The slide is some image-specific offset that seems to change whenever we restart the computer.
    ///         - The slide seems to be the same for all frameworks –> Opptimization potential? No, this has to be way too fast to be worth caching.
    vm_address_t vmaddr_slide = (vm_address_t)mh - (vm_address_t)lc_first_segment->vmaddr;
    
    /// Determine baseAddress for symtabOffsets
    ///     I don't understand why this works or how csbypass people came up with this.
    ///     Claude said "I found several codebases that do this calculation but I don't fully understand the reasoning." (Not sure it hallucinated that, bc it couldn't come up with this calculation by itself.)
    uint64_t offset_base = lc_linkedit_segment->vmaddr + vmaddr_slide - lc_linkedit_segment->fileoff; /// Put the subtraction at the end to prevent possible integer underflows (not sure if necessary)
    
    /// Iterate symbol table
    ///     And find the symbol matching the name we're searching for.
    ///
    ///     Optimization:
    ///         - On bisection.
    ///             - Seems like all external symbols are sorted, letting us use bisection to speed things up.
    ///                 - Non-external symbols are not sorted. -> Not sure there's a better way than linear search. (Except maybe implementing a custom cache, but we should do that at a higher level not here I think.)
    ///             - Example of bisection and toc (table of contents) usage:
    ///                 binarySearchWithToc() inside Apple's ImageLoaderMachOClass.cpp https://github.com/opensource-apple/dyld/blob/3f928f32597888c5eac6003b9199d972d49857b5/src/ImageLoaderMachOClassic.cpp#L865
    const struct nlist_64 *sym_result = NULL;
    
    uint32_t                nsyms       = lc_symtab->nsyms;
    const struct nlist_64   *symtab     = (void *)(offset_base + lc_symtab->symoff);
    const char              *strtab     = (void *)(offset_base + lc_symtab->stroff);
    bool                    bisect      = false;
    
    struct dylib_table_of_contents  *toc = NULL;
    
    /// Optimization: Override params if dysymtab info is available
    ///     dysymtab stuff is complicated and I'm too lazy to really read the docs, not sure if there are more optimization we could make using it.

    if (lc_dysymtab) {
    
        /// Validate
        mfassert((0 == lc_dysymtab->nmodtab     &&  /// Note: I've observed `lc_dysymtab->nindirectsyms` be non-zero but I don't know what it means. Currently we're not using it at all.
                  0 == lc_dysymtab->nextrefsyms &&
                  0 == lc_dysymtab->nextrel     &&
                  0 == lc_dysymtab->nlocrel),
                  @"dysymtab has some fields that we don't know how to handle. I think in some cases the symbols aren't just sorted by name but also grouped by module. We possibly would need to implement extra logic for that. (Source: dysymtab_command docs)");
        
        if (symtabSection == kMFSymbolTableSectionAllSections) {
            /// No optimization -> Just iterate all symbols
        } else if (symtabSection == kMFSymbolTableSectionLocal) {
            /// Linearly search 'local' symbols.
            bisect = false;
            nsyms = lc_dysymtab->nlocalsym;
            symtab = &symtab[lc_dysymtab->ilocalsym];
        } else if (symtabSection == kMFSymbolTableSectionExternallyDefined) {
            /// "Externally defined" symbols are sorted by name so we can bisect them for optimization.
            if (lc_dysymtab->ntoc > 0) {
                /// Bisect the table of contents (toc)
                bisect = true;
                nsyms   = lc_dysymtab->ntoc;
                toc     = (void *)(offset_base + lc_dysymtab->tocoff); /// TODO: Test this. (A toc only appears in dynamic libaries according to the docs.)
            } else if (lc_dysymtab->nextdefsym > 0) {
                /// Bisect the 'externally defined' aka linkable symbols
                bisect  = true;
                nsyms   = lc_dysymtab->nextdefsym;
                symtab  = &symtab[lc_dysymtab->iextdefsym];
            } else {
                mfassert(false); /// Not sure how to handle this. Can we still bisect in this case? Actually, I think `nextdefsym`  should always be present and non-zero (except if there are no externally defined symbols)
            }
        } else if (symtabSection == kMFSymbolTableSectionUndefinedSymbols) {
            /// Search undefined symbols
            ///     I'm pretty sure this is always sorted by name – allowing for bisection – but not entirely sure.
            bisect = true;
            nsyms = lc_dysymtab->nundefsym;
            symtab = &symtab[lc_dysymtab->iundefsym];
        } else {
            mfassert(false, @"Unknown symtab section %lu", (unsigned long)symtabSection);
        }
    } else { /// `lc_dysymtab == NULL`
        mfassert(symtabSection == kMFSymbolTableSectionAllSections, @"Caller specified a specific symtab section to search, but there is no dysymtab load_command to tell us where the different symtab sections are.");
    }
    if (bisect) {
        
        /// Bisection
        ///     Should be faster than linear search (But maybe not much due to CPU/Memory caching stuff favoring linear search?)
    
        int32_t istart = 0;
        int32_t iend   = nsyms-1; /// Not a uint so that it doesn't underflow if nsyms == 0
        
        while (1) {
            if (istart > iend) {
                sym_result = NULL;
                break;
            }
            uint32_t imid = (iend+istart) / 2;
            uint32_t i = !toc ? imid : toc[imid].symbol_index;
            uint32_t strtab_offset = symtab[i].n_un.n_strx;
            const char *symname = (strtab_offset == 0) ? "" : ((char *)strtab + strtab_offset); /// The docs say that the symname is emptyString if the offset is 0. Not sure we need to explicitly implement this.
            
            if ((false) && runningPrerelease()) {
                DDLogDebug(@"(bisection) sym: %s", symname);
                validateSymbol(&symtab[i], symtabSection);
            }
            
            int cmp = strcmp(name, symname);
            if (cmp > 0) {              /// name `>` symname
                istart = imid+1;
            } else if (cmp < 0) {       /// name `<` symname
                iend = imid-1;
            } else {
                sym_result = &symtab[imid];
                break;
            }
        }
    } else {
    
        /// Brute-force linear search
        ///     Note: Based on my (very limited) testing, this is surprisingly fast and almost as fast as the bisection. Maybe something to do with CPU caching or banch-prediction or something.
        
        for (int i = 0; i < nsyms; i++) {
            
            uint32_t strtab_offset = symtab[i].n_un.n_strx;
            const char *symname = (strtab_offset == 0) ? "" : ((char *)strtab + strtab_offset);
            
            if ((false) && runningPrerelease()) {
                DDLogDebug(@"(linearSearch) sym: %s", symname);
                validateSymbol(&symtab[i], symtabSection);
            }
            
            if (strcmp(symname, name) == 0) {
                sym_result = &symtab[i];
                break;
            }
        }
    }
    
    /// Guard: No result
    if (!sym_result) {
        return NULL;
    }
    
    /// Validate address
    if (sym_result->n_value == 0) {
        mfassert(false, @"mfdlsym: The symbol %s which we found seems to have an address of 0. Not sure this ever happens. But the csbypass code checks for this.", name);
        return NULL;
    }
    
    /// Construct function pointer
    void *result = (void *)(uint64_t)(vmaddr_slide + sym_result->n_value); /// csbypass casts to `uint64_t` here, not sure why. Probably unnecessary
    
    /// Return
    return result;
}

static void find_load_commands(const struct mach_header_64 *mh, bool (^__strong _Nullable conditions[])(struct load_command *), int nConditions, struct load_command *_Nullable outLoadCommands[]) {
    
    /// Helper for `mfdlsym()`
    
    /// Fills the `outLoadCommands` buffer such that the first `nConditions` entries are either NULL or the `struct load_command *` from the `mh` (mach-o file header) which matches the corresponding condition from the `conditions` array.
    ///     The caller needs to make sure `outLoadCommands[]` and `conditions[]` are at least as large as `nConditions`, otherwise there will be a *buffer overflow*.
    ///     A condition can be NULL, in which case the condition is ignored and the corresponding loadCommand in the output will be set to NULL.
    /// Notes:
    ///     - Optimization:
    ///         - This whole structure where we have multiple conditions and return values is intended as an optimization, but I haven't tested if it actually makes things faster.
    ///         - Simply iterating over all the load commands should be fast enough. Afaik there are only a few load commands in a mach-o executable (`<` 100 I think) – and I don't think we can bisect them or anything.
    ///     - Based on csbypass: https://github.com/kpwn/935csbypass/blob/f61333d69efa38a4607d80933b9cf168b330935b/cs_bypass.m#L87
    
    /// Guard: resultBuffer != NULL
    if (!outLoadCommands) {
        mfassert(false, @"outLoadCommands was unexpectedly NULL");
        return;
    }
    /// Validate count
    if (nConditions <= 0) {
        mfassert(false, @"nConditions must greater 0");
        return;
    }
    /// Init resultBuffer with NULL
    for (int i = 0; i < nConditions; i++) {
        outLoadCommands[i] = NULL;
    }
    /// Guard: otherArgs != NULL
    if (!mh || !conditions) {
        mfassert(false, @"Some args were unexpectedly NULL. mh: %p, conditions: %p.", mh, conditions);
    }
    
    /// Note:   ... This excessive input-validation might be a bit silly since this is just an internal helper function.
    
    /// Get nUnmetConditions
    int64_t nUnmetConditions = countmatches(conditions, nConditions, c, (c != NULL)); /// We don't need to meet NULL conditions
    
    /// Iterate loadCommands
    struct load_command *lc = (void *)(mh + 1); /// Get first command - they start right after the header || Note: Because of fancy C ptr arithmetic, `+ 1` moves the struct pointer past the struct, not to the next byte.
    for (int i = 0; i < mh->ncmds; i++) {       /// Iterate up to ncmds times
        
        /// Iterate conditions
        for (int j = 0; j < nConditions; j++) {
            
            /// Check if a loadCommand has already been found for this condition.
            if (outLoadCommands[j] != NULL) continue;
            
            /// Check if this loadCommand meets the condition
            bool (^_Nullable condition)(struct load_command *) = conditions[j];
            if (condition && condition(lc)) {
                outLoadCommands[j] = lc;
                nUnmetConditions -= 1;
                /// Note: We don't break here, meaning that multiple conditions could theoretically be met by the same `load_command`
            }
        }
        /// Check if all conditions have been met
        if (nUnmetConditions == 0) {
            break;
        }
        /// Validate cmdsize
        if (lc->cmdsize == 0) {
            mfassert(false, @"Invalid cmdsize detected. Breaking to prevent infinite loop."); /// This is pretty far fetched and would likely never ever ever happen.
            break;
        }
        /// Increment
        /// Note: Cast to 8 bit int ptr so that addition increments the struct ptr in bytes. Alternatively we could also cast to a non-pointer type like `intptr_t` or `uint64_t` for the same effect.
        lc = (void *)((uint8_t *)lc + lc->cmdsize);
    }
}

void *_Nullable mfdlopen(MFFramework framework) {
    
    /// Alternative for `dlopen()`
    ///
    /// Usage & behavior:
    ///     - The resulting handle is meant to be passed to `mfdlsym()` and `mfdlclose()`
    ///     - Returns NULL on failure
    
    /// Get framework path.
    const char *targetframeworkName = safeindex(MFFrameworkToNameMap, arrcount(MFFrameworkToNameMap), framework, NULL);
        
    /// Validate
    if (!targetframeworkName) {
        mfassert(false, @"Framework name couldn't be obtained. framework: %d. namemap count: %lu", framework, arrcount(MFFrameworkToNameMap));
        return NULL;
    }

    /// Clear existing errors
    dlerror(); /// Clear existing errors
    
    /// Open image
    ///     Note: We used to use `RTLD_FIRST` here, to prevent dlsym() from searching "subsequent images". But this shouldn't have an effect on our `mfdlsym()` implementation.
    void *handle = dlopen(targetframeworkName,  RTLD_NOW/*RTLD_LAZY*/     | /** Usually `RTLD_LAZY` is preferred, but not totally sure if it might cause problems inside our custom `mfdlsym()` implementation.  || Under macOS 12+ the now/lazy flags are ignored anyways. || Also see `MFLoadSymbol_native()` where we use `RTLD_LAZY`. */
                                                RTLD_LOCAL/*RTLD_GLOBAL*/ | /** See `MFLoadSymbol_native()` dlopen() call for discussion. */
                                                0/*RTLD_NOLOAD*/          | /** See `MFLoadSymbol_native()` dlopen() call for discussion. */
                                                0/*RTLD_NODELETE*/        | /** Gives user the choice to potentially have the image unmapped later by calling `mfclose()` (AFAIK) */
                                                RTLD_FIRST                | /** Makes dlsym() not search 'subsequent' images. Probably doesn't make a difference since mfdlsym() only searches one image anyways. Also see `MFLoadSymbol_native()` dlopen() call for discussion.*/
                                                0);
    
    /// Return
    return handle;
}

void mfdlclose(void *dlopen_handle) {

    /// Release an image-handle obtained through `mfdlopen()`
    ///     The underlying `dlclose()` decreases the images reference count, which might cause the image to be unmapped from memory (afaik) (also might have other effects that I don't know about.)
    ///
    /// ! Don't use use this !
    ///     (... unless you have good reason to)
    ///     Closing the handle might unmap the image which might make the symbol addresses we obtained through `mfdlsym()` invalid.
    ///     > Only close the handle if you don't plan to use any symbols from the image anymore.
    ///
    ///     (I'm not totally sure my understanding is correct.)
    ///
    ///     The following might suggest that I'm incorrect:
    ///     `man dlclose` says: "A dynamic library will never be unloaded [...] if the main executable directly or indirectly links against it,"
    ///         > Perhaps, us holding a symbol-pointer which points into the image counts as us "linking against" the image – preventing the image from being unloaded despite dlclosing setting the refcount to 0 – But not entirely sure.
    ///         > To be safe it's better to not call mfdlclose().
    ///         > Sidenote: We could also use `RTLD_NODELETE` for `dlopen()` to prevent the image from being unmapped even if the refcount hits 0 due to dlclose()
    
    if (!dlopen_handle) return;
    
    dlerror(); /// Clear existing errors
    int rt = dlclose(dlopen_handle);
    mfassert(rt == 0, @"dlclose failed with error: %s", dlerror());
}

// MARK: - Unused

static uint32_t mf_dyld_framework_index(MFFramework framework) {
    
        
    /// Don't use
    mfassert(false, @"Use dlopen() instead.");
    
    /// Helper for older mfdlopen() implementation.
    ///     Get the frameworks' `index` which is used as a handle in APIs such as `_dyld_get_image_header()`
    ///     Returns `UINT32_MAX` if framework couldn't be found.
    ///
    ///     Restrictions:
    ///         Only searches among images that are already mapped into this process,
    ///             > unlike `dlopen()` which can load new images. (AFAIK)
    ///             (However we're mainly interested in Apple's Frameworks which are always mapped in as part of the `dyld shared cache`)
    ///         Not thread safe:
    ///             According to `_dyld_image_count()` docs and `man 3 dyld`, images could be loaded or unloaded while we're iterating them. Using a while(1) loop should help but I'm not sure if other race-conditions can occur.
    ///             > `dlopen()` seems to aquire multiple locks to prevent any threading issues. (See dlopen() source code at: https://github.com/apple-oss-distributions/dyld/blob/66c652a1f1f6b7b5266b8bbfd51cb0965d67cc44/dyld/DyldAPIs.cpp#L1414)
    ///         Returned framework could be unloaded:
    ///             After we return the `result` index, the framework could be unloaded, making the index potentially unsafe to work with. (Although we're mostly interested in frameworks from the `dyld shared cache` – which should always stay loaded.)
    ///             > `dlopen()` increments the reference count of the image, preventing it from being unloaded and making the returned value safe to work with.
    ///
    ///         > Use `dlopen()` instead of this!
    ///
    ///     Note: Originally, we used this over `dlopen()` because it was the only way  I knew to get a `struct mach_header` for an image given it's name. (By using `_dyld_get_image_header(image_index)` on the index returned by this function.)
    ///     However, now that we discovered the undocumented `_dyld_get_dlopen_image_header(dlopen_handle)` – We don't need this anymore!
    ///
    ///     Other ideas:
    ///     - Do frameworks have a UUID aside from their full load path? Could we use that to speed up framework-search?
    ///         > Apple's dlopen implementation seems to also identify images by path: See `loadPhase5load()`: https://github.com/opensource-apple/dyld/blob/3f928f32597888c5eac6003b9199d972d49857b5/src/dyld.cpp#L2598
    ///         > To make things thread-safe, I think we should probably use `dlopen()` - and that relies on frameworkPath not some UUID.
    ///         > IIRC I saw in some source code that there is a framework UUID, but the entire `dyld shared cache` shares one UUID – so it's not that useful.
    
    /// Query map
    const char *targetframeworkName = safeindex(MFFrameworkToNameMap, arrcount(MFFrameworkToNameMap), framework, NULL);
    
    /// Guard
    if (!targetframeworkName) {
        mfassert(false, @"No framework name found for MFFramework %lu", (unsigned long)framework);
        return UINT32_MAX;
    }
    
    /// Find framework index
    /// Notes:
    /// - Not sure how inefficient this is.
    /// - We iterate with a `while (1)` loop because the `man 3 dyld` docs say these functions aren't thread safe and the number of images could change while we're iterating.
    ///     -> Not sure the while-loop helps.
    ///     -> `man 3 dyld` also says that `dladdr()` is a thread-safe alternative.
    uint32_t frameworkIndex;
    uint32_t i = 0;
    while (1) {
        const char *imageName = _dyld_get_image_name(i); /// Docs at `man 3 dyld`
        if (!imageName) {
            frameworkIndex = UINT32_MAX;
            break;
        }
        if (strcmp(imageName, targetframeworkName) == 0) {
            frameworkIndex = i;
            break;
        }
        i++;
    }
    
    /// Return
    return frameworkIndex;
}

void *_Nullable MFLoadPrivateFunction_WithHardCodedAddress(MFFramework framework, intptr_t symbolOffset) {
    
    mfassert(false); /// Probably don't use this.
    
    /// Result: This works
    ///     However, relying on hardcoding the functionOffset feels quite brittle.
    ///
    /// Find the functionOffset in lldb
    ///         Example: `image lookup -v -n GetKeyboardType` -> `0x000000018ba88dd0`
    ///
    /// Alternative implementations:
    ///     - Maybe use `_dyld_all_image_infos` or `dyld_shared_cache_ranges` (See `dyld_images.h`)
    ///     - Maybe use `task_get_dyld_image_infos`? Haven't looked into that.
    ///     - We could, instead of the `image_vmaddr_slide`, get the loadAddress of the framework's `__TEXT.__text` section.
    ///         The functionPointer's offset from that text section can also be obtained through `image lookup -v -n GetKeyboardType`
    ///

    /// Get framework index
    int frameworkIndex = mf_dyld_framework_index(framework);
    if (frameworkIndex == UINT32_MAX) return NULL;
    
    /// Find framework's slide
    ///     Note: The slide seems to be the same for all frameworks, so maybe we could make this more efficient?
    intptr_t slide = _dyld_get_image_vmaddr_slide(frameworkIndex); /// `man 3 dyld` says: `If image_index is out of range zero is returned.`. However, I think valid frameworks might also have a slide of 0?
    
    /// Construct function ptr
    void *result = (void *)(slide + symbolOffset);
    
    /// Return
    return result;
}

void *_Nullable MFLoadPrivateFunction_WithNSImageFunctions(MFFramework framework, const char *symbolName) {
    
    mfassert(false); /// Outdated. Use other functions like `mfdlsym()` instead.
    
    /// Result:
    ///     This works for **externally defined** symbols like `_LMGetKbdLast`, but not for **local** symbols like `_GetKeyboardType()` (which is what we're interested in.)
    ///     So it's not better than `dlsym()`
    ///
    ///    Notes:
    ///    - The NSImage APIs are a (deprecated) alternative to the new dlsym() APIs.
    ///     - I couldn't find docs but the public NSAddImage() source code clears things up: https://github.com/opensource-apple/dyld/blob/master/src/dyldAPIs.cpp#L968
    ///     - Example code for NSAddImage() and NSLookupSymbolInImage() from Firefox source code: https://github.com/jrmuizel/gecko-cinnabar/blob/master/xpcom/glue/standalone/nsXPCOMGlue.cpp
    
    ///
    /// Alternatives:
    ///     - NSLinkModule() ?
    ///         Perhaps in tandem with `NSMakePrivateModulePublic()`? Which can maybe be accessed using `_dyld_func_lookup()` (I'm confused.)
    
    /// Disable deprecation warnings
    #pragma GCC diagnostic push
    #pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    
    /// Query map
    const char *targetframeworkName = (framework >= arrcount(MFFrameworkToNameMap)) ? NULL : MFFrameworkToNameMap[framework];
    
    /// Get framework's image
    const struct mach_header *imageHeader = NSAddImage(targetframeworkName,
                                                 NSADDIMAGE_OPTION_WITH_SEARCHING | /** Internally called `useSearchPaths` and `useFallbackPaths`. Probably refers to how the image is loaded. Might also refer to whether we can search in the loaded image? Not sure. */
                                                 NSADDIMAGE_OPTION_RETURN_ON_ERROR | /** Internally called `!abortOnError` */
                                                 /* NSADDIMAGE_OPTION_RETURN_ONLY_IF_LOADED */ /** Internally called `dontLoad` */
                                                 NSADDIMAGE_OPTION_MATCH_FILENAME_BY_INSTALLNAME); /** No idea what this does. Mentioned in this BugZilla report: https://bugzilla.mozilla.org/show_bug.cgi?id=578692 */;
    
    /// Find symbol in image
    NSSymbol symbol = NSLookupSymbolInImage(imageHeader, symbolName,
                                            NSLOOKUPSYMBOLINIMAGE_OPTION_RETURN_ON_ERROR |    /** I assume this makes it so we don't crash if the symbol lookup fails (Assuming this works like `NSADDIMAGE_OPTION_RETURN_ON_ERROR`)*/
                                            0 /* NSLOOKUPSYMBOLINIMAGE_OPTION_BIND */ |               /** Looking at source code this seems to do nothing */
                                            0 /* NSLOOKUPSYMBOLINIMAGE_OPTION_BIND_NOW */ |           /** Looking at src code this calls `bindAllLazyPointers` on the image || Maybe to extreme? */
                                            0 /* NSLOOKUPSYMBOLINIMAGE_OPTION_BIND_FULLY */);        /** Looking at src code this calls `bindAllLazyPointers` on the image */
    /// Get symbol's address
    void *result = NSAddressOfSymbol(symbol);
    
    /// Return
    return result;
    
    /// Enable deprecation warnings
    #pragma CGG diagnostic pop
}

@end

// MARK: - Testing

#define MF_TEST 0

#if MF_TEST

#import "MFBenchmark.h"

@implementation PrivateFunctions (MFLoadTests)

+ (void)load {
        do_dynamic_load_benchmarks();
}

void do_dynamic_load_benchmarks(void) {
    
    /// Test how fast this stuff is (pretty fast)
    
    /// Setup benchmarking
    ///     Note: Deactivate Breakpoints in Xcode to see real performance (That tells you this is pretty fast.)
    
    mfbench_init(100)
    
    typedef CGEventSourceKeyboardType MFKeyboardType;
    
    MFKeyboardType (*fn)(void)  = NULL;
    MFKeyboardType (*fn2)(void) = NULL;
    void (*fnx)(void)           = NULL;
    
    if ((true)) {
        /// Approach two: Custom symbol lookup
        
        _scopeins_statement_start(({                                \
            __mfbench_labels[__mfbench_n] = ("dlopen skylight");      \
            __mfbench_ts[__mfbench_n*2] = CACurrentMediaTime();     \
        }));                                                        \
        
        void *dl_skylight   = NULL;
        void *dl_hitoolbox  = NULL;
        void *skylight      = NULL;
        void *hitoolbox     = NULL;
        
        /// 0. Test dlopen on SkyLight
        mfbench("dlopen skylight")
            dl_skylight = dlopen(MFFrameworkToNameMap[kMFFrameworkSkyLight], RTLD_LAZY | RTLD_LOCAL | RTLD_FIRST); /// Not totally sure what options to use.)
        
        /// 1. Test dlopen on HIToolbox
         mfbench("dlopen hitoolbox")
            dl_hitoolbox = dlopen(MFFrameworkToNameMap[kMFFrameworkHIToolbox], RTLD_LAZY | RTLD_LOCAL | RTLD_FIRST); /// Not totally sure what options to use.)
        
        /// 2. Test mfdlopen on SkyLight
         mfbench("mfdlopen skylight")
            skylight = mfdlopen(kMFFrameworkSkyLight);
        
        /// 3. Test mfdlopen on HIToolbox
         mfbench("mfdlopen hitoolbox")
            hitoolbox = mfdlopen(kMFFrameworkHIToolbox);
        
        /// 4. Test 'local' function loading
         mfbench("test 4")
            fnx = mfdlsym(hitoolbox, kMFSymbolTableSectionLocal, "_TSMInputSourceGetTypeID");
        
        /// 5. Test dlsym
         mfbench("test 5")
            fnx = dlsym(dl_hitoolbox, "TISInputSourceGetTypeID");
        
        /// 6. Test mfdlsym
         mfbench("test 6")
            fnx = mfdlsym(hitoolbox, kMFSymbolTableSectionExternallyDefined, "_TISInputSourceGetTypeID");
        
        /// 7. Get HIToolbox function (local)
         mfbench("test 7")
            fn = mfdlsym(hitoolbox, kMFSymbolTableSectionLocal, "_GetKeyboardType");
        
        /// 8. Get SkyLight function (mfdlsym)
         mfbench("test 8")
            fn2 = mfdlsym(skylight, kMFSymbolTableSectionExternallyDefined, "_SLSGetLastUsedKeyboardID");
        
        /// 9. Get SkyLight function (dlsym)
         mfbench("test 9")
            fnx = dlsym(dl_skylight, "_SLSGetLastUsedKeyboardID");
        
        /// 10. Benchmark repeat
         mfbench("test 10")
            fn2 = mfdlsym(skylight, kMFSymbolTableSectionExternallyDefined, "_SLSGetLastUsedKeyboardID");
        
        /// 11. Benchmark repeat 2
         mfbench("test 11")
            fnx = mfdlsym(skylight, kMFSymbolTableSectionExternallyDefined, "_SLSGetLastUsedKeyboardID");
    }
    
    MFKeyboardType result;
    
    /// 14: Call fn
    mfbench("test 14") result = fn ? fn() : UINT32_MAX;
    
    /// 15: Call fn (repeat)
    mfbench("test 15") result = fn ? fn() : UINT32_MAX;
    
    /// 12: Call fn2
    mfbench("test 12") result = fn2 ? fn2() : UINT32_MAX;
    
    /// 13: Call fn2 (repeat)
    mfbench("test 13") result = fn2 ? fn2() : UINT32_MAX;
    
    /// Assemble results
    NSMutableArray<MFBenchResult *> *benchmarkResults = mfbench_results();
    
    /// Print
    NSLog(@"Dynamic load benchmarks:\n%@", mfbench_format_results(benchmarkResults));
}

@end

#endif
