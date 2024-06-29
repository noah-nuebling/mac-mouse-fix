
# pip imports
import babel

# stdlib&local imports
import json
from collections import defaultdict
import re
import os
import mfutils

#
# Constants
#

language_flag_fallback_map = { # When a translation's languageID doesn't contain a country, fallback to these flags
    'zh': '🇨🇳',       # Chinese maps to China
    'ko': '🇰🇷',       # Korean maps to South Korea
    'de': '🇩🇪',       # German maps to Germany
    'vi': '🇻🇳',       # Vietnamese maps to Vietnam
    'en': '🇬🇧',       # English maps to UK
}

language_name_override_map = {
    'en': {
        'zh-HK': 'Chinese (Honk Kong)', # The native Babel name for this locale is way too long. This is name used by Apple.
    },
    'zh-HK': {
        'zh-HK': '中文（香港)',
    }
}

#
# Language stuff
#

def get_localization_progress(xcstring_objects: list[dict], translation_locales: list[str]) -> dict:
    
    """
    - You pass in a list of xcstrings objects, each of which is the content of an xcstrings parsed using json.load()
    - The return is a dict with structure:
        {
            '<locale>': {
                'translated': <number of translated strings>,
                'to_translate': <number of strings that should be translated overall>,
                'percentage': <percentage of strings that should be translated, which actually have been translated>
        }
        
        - Note that strings which are marked as 'stale' in the development language are not considered 'strings that should be translated'. Since the 'stale' state means that the string isn't used in the source files.
    """
    
    # Create an overview of how many times each translation state appears for each language
    
    localization_state_overview = defaultdict(lambda: defaultdict(lambda: 0))
    for xcstring_object in xcstring_objects:
        for key, string_dict in xcstring_object['strings'].items():
            
            for locale in translation_locales:
                
                s = string_dict.get('localizations', {}).get(locale, {}).get('stringUnit', {}).get('state', 'mmf_indeterminate')
                assert(s == 'new' or s == 'needs_review' or s == 'translated' or s == 'stale' or s == 'mmf_indeterminate')        
                
                localization_state_overview[locale][s] += 1
    
    localization_state_overview = json.loads(json.dumps(localization_state_overview)) # Convert nested defaultdict to normal dict - which prints in a pretty way
    
    # Get translation progress for each language
    #   Notes: 
    #   - Based on my testing, this seems to be accurate except that it didn't catch the missing translations for the Info.plist file. That's because the info.plist file doesn't have an .xcstrings file at the moment but we can add one.
    
    localization_progress = {}
    for locale, states in localization_state_overview.items():
        translated_count = states.get('translated', 0)
        to_translate_count = states.get('translated', 0) + states.get('needs_review', 0) + states.get('new', 0) + states.get('mmf_indeterminate', 0) # Note how we're ignoring stale strings here. (Stale means that the kv-pair is superfluous and doesn't occur in the base file/source code file afaik, therefore it's not part of 'to_translate' set)
        localization_progress[locale] = {'translated': translated_count, 'to_translate': to_translate_count, 'percentage': translated_count/to_translate_count}

    # Return
    return localization_progress

def get_translation(xcstrings: dict, key: str, preferred_locale: str) -> tuple[str, str]:
    
    """
    -> Retrieves a `translation` for key `key` from `xcstrings` for the `preferred_locale`
    
    -> Returns a tuple with structure: (translation, locale_of_the_translation)
    
    If no translation is available for the preferred_locale, it will fall back to the next best language. 
        - For example, it could fall back from Swiss German to Standard German, if a String only has a German and English version. (Haven't tested this) 
        - As a last resort it will always fall back to the development language (English)
        - This logic is implemented by babel.negotiate_locale, and I'm not sure how exactly it behaves.

    Notes: 
    - The xcstrings dict is the content of an .xcstrings file which has been loaded using json.load()
    """
    
    assert xcstrings['version'] == '1.0' # Maybe we should also assert this in other places where we parse .xcstrings files
    
    source_locale = xcstrings['sourceLanguage']
    localizations = xcstrings['strings'][key]['localizations']
    
    available_locales = localizations.keys()
    preferred_locales = [preferred_locale, source_locale] # The leftmost is the most preferred in babel.negotiate_locale
    best_locale = babel.negotiate_locale(preferred_locales, available_locales) # What's the difference to babel.Locale.negotiate()?
    
    translation = localizations[best_locale]['stringUnit']['value']
    
    assert translation != None and len(translation) != 0
    
    return translation, best_locale
        

def make_custom_xcstrings_visible_to_xcodebuild(path_to_xcodeproj: str, custom_xcstrings_paths: list) -> dict:
    
    # Load xcode project as json
    #   I have no idea why plutil can do this - .pbxproj files aren't .plist files?
    pbxproject_json = json.loads(mfutils.runCLT(f"plutil -convert json -r -o - {path_to_xcodeproj}/project.pbxproj").stdout)
        
    for xcstrings_path in custom_xcstrings_paths:

        # Find xcstrings file
        xcstrings_name = os.path.basename(xcstrings_path) # Just ignore the path, just use the name
        xcstrings_uuids = []
        for uuid, info in pbxproject_json['objects'].items():
            if info['isa'] == 'PBXFileReference' and info['path'] == xcstrings_name:
                xcstrings_uuids.append(uuid)
        
    # Validate
    #   This will fail if the xcstrings file's name is not unique throughout the project, or if the xcstrings files doesn't exist in the project.
    assert len(xcstrings_uuids) == 1
    
    # Extract
    xcstrings_uuid = xcstrings_uuids[0]
    
    # Create PXBuildFile object
    
    build_file_key = mfutils.xcode_project_uuid()
    build_file_value = {
         "fileRef" : xcstrings_uuid,
         "isa" : "PBXBuildFile"
      },
    
    # Insert PXBuildFile into xcode project
    mfutils.runCLT(f"plutil -insert objects.{build_file_key} -json '{json.dumps(build_file_value)}' {path_to_xcodeproj}/project.pbxproj")
    
    # Create 'undo payload'
    #   Pass this to the undo function to undo the changes that this function made
    undo_payload = {
        'project': path_to_xcodeproj,
        'inserted_build_file_key': build_file_key,
    }
    
    # Return
    return undo_payload
    

def find_locales(path_to_xcodeproj) -> tuple[str, list[str]]:
    
    """
    Returns the development locale of the xcode project as the first argument and the list of translation locales as the second argument
    """
    
    pbxproject_json = json.loads(mfutils.runCLT(f"plutil -convert json -r -o - {path_to_xcodeproj}/project.pbxproj").stdout) # -r puts linebreaks into the json which makes it human readable, but is unnecessary here. `-o -` returns to stdout
    
    development_locale = None
    locales = None
    for obj in pbxproject_json['objects'].values():
        if obj['isa'] == 'PBXProject':
            locales = obj['knownRegions']
            development_locale = obj['developmentRegion']
            break
    
    assert(development_locale != None and locales != None and len(locales) >= 1)
    
    # Filter out development locale and 'Base' locale
    translation_locales = [l for l in locales if l != development_locale and l != 'Base']
    
    return development_locale, translation_locales
    

def language_tag_to_language_name(language_id: str, destination_language_id: str = 'en', include_flag = False):
    
    language_name = language_name_override_map.get(destination_language_id, {}).get(language_id)
    
    if language_name == None:
            
        locale_obj = babel.Locale.parse(language_id, sep='-')
        destination_locale_obj = babel.Locale.parse(destination_language_id, sep='-')
        
        language_name = locale_obj.get_display_name(destination_locale_obj) # .display_name is the native name, .english_name is the english name
    
    if include_flag:
        language_name = f"{language_tag_to_flag_emoji(language_id)} {language_name}"
    
    return language_name

def language_tag_to_flag_emoji(language_id):
    
    # Define helper
    def get_flag(country_code):
        return ''.join(chr(ord(c) + 127397) for c in country_code.upper())
    
    # Parse language tag
    locale = babel.Locale.parse(language_id, sep='-')
    
    # Get flag from country code
    if locale.territory:
        return get_flag(locale.territory)
    
    # Fallback
    flag = language_flag_fallback_map.get(locale.language, None)
    if flag:
        return flag
    
    # Fallback to Unicode 'Replacement Character' (Missing emoji symbol/questionmark-in-rectangle symbol)
    return "&#xFFFD;" 

#
# Markdown parsing (Localizable strings)
#

def get_localizable_strings_from_markdown(md_string: str) -> list[tuple[str, str, str, str]]:

    """
    Returns a list of localizable strings extracted from the `md_string`.
    
    Each tuple in the list has the structure (key, value, comment, full_match)
        key: 
            a.key.that identifies the string across different languages
        value: 
            The user-facing string in the development language (english). The goal is to translate this string into differnt languages.
        comment: 
            A comment providing context for translators.
        full_match: 
            The entire substring of the .md file that we extracted the key, value, and comment from. Replace all full_matches with translated strings to localize the .md file.
    
    The localizable strings inside the .md file can be specified in 2 ways: Using the `inline syntax` or the `block syntax`.
    
    The `inline sytax` follows the pattern:
    
        {{value||key||comment}}
        
        Examples:

            bla blah {{🙌 Acknowledgements||acknowledgements.title||This is the title for the acknowledgements document!}}
            
            blubb
            
            bli blubb {{😔 Roasting of Enemies||roast.title||This is the title for the roasting of enemies document!}} blah
    
    The `block syntax` follows the pattern:

        ```
        key: <key>
        ```
        <value>
        ```
        comment: <comment>
        ```
        
        Example:
        
            ```
            key: acknowledgements.body
            ```
            Big thanks to everyone using Mac Mouse Fix.

            I want to especially thank the people and projects named in this document.
            ```
            comment: This is the intro for the acknowledgements document
            ```
            

    Keep in mind!
    
        For the `block_syntax`, any free lines directly above or below the <value> will be ignored and removed. 
        
        So it doesn't make any difference whether the markdown source looks like this:

            ```
            key: <key>
            ```
            abcefghijklmnop
            qrstuvwxyz
            ```
            comment: <comment>
            ```
        
        Or like this:
            
            ```
            key: <key>
            ```
            
            
            
            abcefghijklmnop
            qrstuvwxyz
            
            
            
            ```
            comment: <comment>
            ```
        
        -> I tried to respect the free lines around the <value>, but I couldn't ge the regex to work like that. But honestly, it's probably better this way. 
            Since, this way, translators will never have to add blank lines above or below their content to make the layout of the .md file work as intended.
            
    Notes:
    - Use https://regex101.com to design and test regexes like the ones used here.
    - To test, you might want to post the whole .md file on regex101. That way you can see any under or overmatching which might not be obvious when testing a smaller example string.
    
    """

    # Extract translatable strings with inline syntax

    inline_regex = r"\{\{(.*?)\|\|(.*?)\|\|(.*?)\}\}"           # r makes it so \ is treated as a literal character and so we don't have to double escape everything
    inline_matches = re.finditer(inline_regex, md_string)
    
    # Extract translatable strings with block syntax
    
    block_regex = r"```\n\s*?key:\s*(.*?)\s*\n\s*?```\n\s*(^.*?$)\s*```\n\s*?comment:\s*?(.*?)\s*\n\s*?```" 
    block_matches = re.finditer(block_regex, md_string, re.DOTALL | re.MULTILINE)

    # Assemble result

    all_matches = list(map(lambda m: ('inline', m), inline_matches)) + list(map(lambda m: ('block', m), block_matches))
    
    result = []
        
    for match in all_matches:
        
        # Get info from match
        
        full_match = match[1].group(0)
        comment = None
        value = None
        key = None
        
        if match[0] == 'inline':
            value, key, comment = match[1].groups()
        elif match[0] == 'block':
            key, value, comment = match[1].groups()    
        else: 
            assert False    

        # Validate
        assert ' ' not in key, f'key contains space: {key}' # I don't think keys are supposed to contain spaces in objc and swift. We're trying to adhere to the standard xcode way of doing things. 
        assert len(key) > 0   # We need a key to do anything useful
        assert len(value) > 0 # English ui strings are defined directly in the markdown file - don't think this should be empty
        for str in [value, key, comment]:
            assert r'}}' not in str # Protect against matching past the first occurrence of }}
            assert r'||' not in str # Protect against ? - this is weird
            assert r'{{' not in str # Protect against ? - this is also weird
        # TODO: Maybe somehow protect against over matching on block syntax, too
        
        # Store
        result.append((key, value, comment, full_match))
    
    # Return
    
    return result