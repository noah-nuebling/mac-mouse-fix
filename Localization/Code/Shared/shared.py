#
# Imports
#

import tempfile
import difflib
import subprocess
import os
import re
import git
import textwrap
import glob
import requests
import json
import babel
from collections import defaultdict

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
        'zh-HK': 'Chinese (Honk Kong)', # The native Babel name for this locale is way to long. This is name used by Apple.
    },
    'zh-HK': {
        'zh-HK': '中文（香港)',
    }
}

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
        assert ' ' not in key, f'key contains space: {key}' # I don't think string keys are supposed to contain spaces inside the Xcode toolchain stuff
        assert len(key) > 0 # We need a key to parse this
        assert len(value) > 0 # English ui strings are defined directly in the markdown file - don't think this should be empty
        for str in [value, key, comment]:
            assert r'}}' not in str # Protect against matching past the first occurrence of }}
            assert r'||' not in str # Protect against ? - this is weird
            assert r'{{' not in str # Protect against ? - this is also weird
        
        # Store
        result.append((key, value, comment, full_match))
    
    # Return
    
    return result
            
#
# Basic String Processing
#

def get_indent(string: str) -> tuple[int, chr]:
    
    # Split into lines
    lines = string.split('\n')
    
    # Remove lines empty lines (ones that have no chars or only whitespace)
    def is_empty(string: str):
        return len(string) == 0 or all(character.isspace() for character in string)
    lines = list(filter(lambda line: not is_empty(line), lines))
    
    indent_level = 0
    break_outer_loop = False
    
    while True:
        
        # Idea: If all lines have a an identical whitespace at the current indent_level, then we can increase the indent_level by 1. 
        #   Note: GitHub Flavoured Markdown apparently considers 1 tab equal to 4 spaces. Don't know how we could handle that here. We'll just crash on tab.
        
        last_line = None
        for line in lines:
            
            assert line[indent_level] != '\t' # Tabs are weird, we're not sure how to handle them.
            
            is_space = line[indent_level].isspace()
            is_differnt = line[indent_level] != last_line[indent_level] if last_line != None else False
            if not is_space or is_differnt : 
                break_outer_loop = True; break;
            last_line = line
        
        if break_outer_loop:
            break    
        
        indent_level += 1
    
    indent_char = None if indent_level == 0 else lines[0][0]

    return indent_level, indent_char

def set_indent(string: str, indent_level: int, indent_character: chr) -> str:
    
    # Get existing indent
    old_level, old_characer = get_indent(string)
    
    # Remove existing indent
    if old_level > 0:
        unindented_lines = []
        for line in string.split('\n'):
            unindented_lines.append(line[old_level:])
        string = '\n'.join(unindented_lines)
    
    # Add new indent
    if indent_level > 0:
        indented_lines = []
        for line in string.split('\n'):
            indented_lines.append(indent_character*indent_level + line)
        string = '\n'.join(indented_lines)
    
    # Return
    return string
    

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
        

def find_locales(path_to_xcodeproj) -> tuple[str, list[str]]:
    
    """
    Returns the development locale of the xcode project as the first argument and the list of translation locales as the second argument
    """
    
    pbxproject_json = json.loads(runCLT(f"plutil -convert json -r -o - {path_to_xcodeproj}/project.pbxproj").stdout) # -r puts linebreaks into the json which makes it human readable, but is unnecessary here.
    
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
    
    flag = language_flag_fallback_map.get(locale.language, None)
    if flag:
        return flag
    
    # Fallback to Unicode 'Replacement Character' (Missing emoji symbol/questionmark-in-rectangle symbol)
    return "&#xFFFD;" 

# 
# GitHub integration
#

def response_description(response: requests.Response) -> str:
    
    # Notes:
    # - We return the status, the headers, and the body of the response
    # - For the body we try to parse it as json. If that doesn't work we return plain text instead.
    #   - `text`, `content`, and `json` are all different representations for the main body of the response as far as I understand. According to ChatGPT, if only part of the body is parsable as json, then .json() would not be None, but yet, `text` or `content` could contain extra info. In that case we're missing this extra info. I don't think this will matter.
    
    status = response.status_code
    headers = response.headers
    body_text = response.text
    body_content = response.content
    body_json = None
    try:
        body_json = response.json()
    except:
        body_json = None
    
    body = body_json if body_json != None else body_text
    
    return_data = {
        'status': status,
        'headers': dict(headers), # Need to convert this since it's a "CaseSensitiveDict"
        'body': body,
    }
    
    return json.dumps(return_data, indent=2)

def github_rest_api_headers(api_key, for_uploading_binary=False): # Found these values in the github docs
    
    result = {
        'Accept': 'application/vnd.github+json',
        'Authorization': f'Bearer {api_key}',
        'X-GitHub-Api-Version': '2022-11-28',
    }
    if for_uploading_binary:
        result = { 
            **result, 
            **{ 'Content-Type': 'application/octet-stream' }
        }
        
    return result

def github_releases_get_release_with_tag(api_key, owner_and_repo, tag):
    response = requests.get(f'https://api.github.com/repos/{owner_and_repo}/releases/tags/{tag}', headers=github_rest_api_headers(api_key))
    assert 200 <= response.status_code < 300, f'GitHub Release retrieval failed. Code: { response.status_code }, JSON: { response.json() }'
    return response

def github_releases_list_assets_for_release(api_key, owner_and_repo, release_id):
    # Notes
    # - We don't need to use this. The json that github_releases_get_release_with_tag() returns already contains a list of assets
    
    assert(False)
    
    response = requests.get(f'https://api.github.com/repos/{owner_and_repo}/releases/{release_id}/assets', headers=github_rest_api_headers(api_key))
    return response

def github_releases_delete_asset(api_key, owner_and_repo, asset_id):
    response = requests.delete(f'https://api.github.com/repos/{owner_and_repo}/releases/assets/{asset_id}', headers=github_rest_api_headers(api_key))
    assert 200 <= response.status_code < 300, f'GitHub Release asset deletion failed. Code: { response.status_code }, JSON: { response.json() }'
    return response

def github_releases_upload_asset(api_key, owner_and_repo, release_id, asset_name, asset_binary_data):
    headers = github_rest_api_headers(api_key, for_uploading_binary=True)
    response = requests.post(f'https://uploads.github.com/repos/{owner_and_repo}/releases/{release_id}/assets?name={asset_name}', headers=headers, data=asset_binary_data)
    assert 200 <= response.status_code < 300, f'GitHub Release asset upload failed. Code: { response.status_code }, JSON: { response.json() }'
    return response

def github_gists_request(api_key, data):
    
    # Notes:
    # - We intended to upload our .xcloc files to gists, but that seems impossible. Trying to use gh releases for filehosting instead
    
    pass

def github_graphql_request(api_key, query):

    # Notes:
    # - Use GitHub GraphQL Explorer to create queries (https://docs.github.com/en/graphql/overview/explorer)

    # Define header
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    # Make request
    response = requests.post('https://api.github.com/graphql', json={'query': query}, headers=headers)

    # Parse the response
    result = response.json()
    
    # Return 
    return result

def escape_for_markdown(s):
    
    # This is to make `s` display verbatim in markdown.
    # Update: This is not necessary anymore after we started using `escape_for_upload()`
    
    return s #.replace(r'\n', r'\\n').replace(r'\t', r'\\t').replace(r'\r', r'\\r')

def escape_for_upload(s):
    # This is to be able to upload a string through the GitHub GraphQL API.
    # Src: https://www.linkedin.com/pulse/graphql-parse-errors-parul-aditya-1c
    
    # return s.replace('"', r'\"')#.replace(r'+', r'\+').replace(r'\\', r'\\\\')
    
    return (s.replace("\\", "\\\\")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t")
            .replace("\f", "\\f")
            .replace('"', '\\"'))

#
# File-level analysis
#

def extract_translation_keys_and_values_from_file(file_path):
    
    """
    Structure of result: Same as extract_translation_keys_and_values_from_string()
    """
    
    # Read file content
    text = ''
    with open(file_path, 'r') as file:
        text = file.read()

    # Get extension
    _, file_type = os.path.splitext(file_path)
    
    if file_type == '.xib' or file_type == '.storyboard':
        
        # Extract strings from IB file    
        temp_file_path = extract_strings_from_IB_file_to_temp_file(file_path)
        strings_text = read_tempfile(temp_file_path)

        # Call
        result = extract_translation_keys_and_values_from_string(strings_text)
    else: 
        result = extract_translation_keys_and_values_from_string(text)
    
    # Return
    return result
    
#
# Core string-level analysis
#

def strings_file_regex_comment_line():
    
    """
    Matches comments in Xcode .strings files
    
    Test strings:

/* Class = "NSTabViewItem"; label = "Buttons"; ObjectID = "Mjk-wy-Z7C"; Note = "Toolbar > Buttons Tab Button"; */
"Mjk-wy-Z7C.label" = "按鈕";

/* Class = "NSButtonCell"; title = "Trackpad Simulation"; ObjectID = "N65-aN-Hxp"; Note = "Scroll > Trackpad Interactions"; */
"N65-aN-Hxp.title" = "模擬觸控式軌跡板";

/* Class = "NSButtonCell"; title = "Trackpad Simulation"; ObjectID = "N65-aN-Hxp"; Note = "Scroll > Trackpad Interactions"; */
"N65-aN-Hxp.title" = "模擬觸控式軌跡板"; // Whatt

         
 // Hi thereee
	

/* Class = "NSTextFieldCell"; title = "Move the mouse pointer inside the '+' field, then *Click* a mouse button to assign an action to it.  You can also *Double Click*, *Click and Drag* and [more]()."; ObjectID = "N7H-9j-DIr"; Note = "Buttons > Add Field Hint || It's better to use * instead of _ for emphasis. _ causes problems in some languages like Chinese."; */
"N7H-9j-DIr.title" = "移動滑鼠指標到「+」區域內，然後按一下滑鼠按鈕來指定動作。  您也可以按兩下、按一下並拖移、執行[更多]()動作。";

/* Class = "NSMenuItem"; title = "Minimize"; ObjectID = "NdF-Gb-mOK"; */
"NdF-Gb-mOK.title" = "縮到最小";

/* Class = "NSTextFieldCell"; title = "Visit the Website"; ObjectID = "Ozk-o9-C4a"; */
"Ozk-o9-C4a.title" = "參訪網站";

    """
    
    regex = re.compile(r'^ *?\/\*.*?\*\/(\s\/\/.*?)?$', re.MULTILINE)
    
    return regex

def strings_file_regex_blank_line():
    
    """
    Matches blank lines in Xcode .strings files
    
    Test strings: 
        See strings_file_regex_comment_line()
    """
    
    regex = re.compile(r'^\s*?(\s\/\/.*?)?$', re.MULTILINE)
    
    return regex

def strings_file_regex_kv_line():
    
    """
    Used to get keys and values from strings files. Designed to work on Xcode .strings files and on the .js strings files used on the MMF website. (Won't work on `.stringsdict`` files, those are xml)
      
    See https://regex101.com
      
    Group 0: The whole line
    Group 1: git lineDiff. '+', '-' or None
    Group 2: Key
    Group 3: Value
    Group 4: Useless
    Group 5: !IS_OK string
    
    Some test strings:    
    
'quote-"source".,//youtubeComment':  "**{ name }** in// einem YouTube,-KommentarIS_OK", // ! omgg !!IS_OK ,that's so 
+  'quote-source.youtubeComment':  "**{ name }** in' einem'` YouTube`-Kommentar", // IS_OK
    'quote-source.youtubeComment':  "**{ name }** in einem YouTube-Kommentar", /* !IS_OK */
-  "quote-"source".,//youtubeComment" =  '**{ name }** in// einem YouTube,-KommentarIS_OK'; // ! omgg !!is_ok ,that's so 
    """
    
    regex = re.compile(r'^(\+?\-?)\s*[\'\"](.+)[\'\"]\s*[=:]\s*[\'\"](.*)[\'\"][,;].*?(\/.*?(!+IS_OK).*)?$', re.MULTILINE | re.IGNORECASE)
    
    return regex
    
def extract_translation_keys_and_values_from_string(text):

    """
    Extract translation keys and values from text. Should work on Xcode .strings files and nuxt i18n .js files.
    Structure of result:
    {
        "<translation_key>": {
            "added"<?>: { "text": "<translation_value>", "is_ok_count": <number>},
            "deleted"<?>: { "text": "<translation_value>", "is_ok_count": <number>},
            "value"<?>: { "text": "<translation_value>", "is_ok_count": <number>},
        }
        "<translation_key>": {
            ...
        },
        ... 
    }

    ... where <?> means that the key is optional. 
        If the input text is a git diff text with - and + at the start of lines, then the result with contain `added` and `deleted` keys, otherwise, the result will contain `value` keys.
    """
    
    # Get regex 
    regex = strings_file_regex_kv_line()
    
    # Find matches
    matches = regex.finditer(text)
    
    # Parse matches
    
    result = dict()
    for match in matches:
        git_line_diff = match.group(1)
        translation_key = match.group(2)
        translation_value = match.group(3)
        is_ok = match.group(5)
        
        d = 'added' if git_line_diff == '+' else 'deleted' if git_line_diff == '-' else 'value'
        k = is_ok.count('!') if is_ok != None else 0
        
        result.setdefault(translation_key, {})[d] = {"text": translation_value, "is_ok_count": k}
        
        # if translation_key == 'customization-feature.action-table.body':
        #     print(f"NEW_MATCH: {git_line_diff} --- {translation_key} --- {translation_value}, text: {text}")
        
        # if translation_key == 'capture-toast.body':
            # print(f"{git_line_diff} value: {translation_value} isNone: {translation_value is None}") # /Users/Noah/Desktop/mmf-stuff/mac-mouse-fix/Localization/de.lproj/Localizable.strings
            # print(f"result: {result}")
    
    # Return
    return result

#
# Analysis helpers
#

def create_temp_file(suffix=''):
    
    # Returns temp_file_path
    #   Use os.remove(temp_file_path) after you're done with it
    
    temp_file_path = ''
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
        temp_file_path = temp_file.name
    return temp_file_path

def extract_strings_from_IB_file_to_temp_file(ib_file_path):

    # Create empty file
    temp_file_path = create_temp_file()
        
    # Check if empty
    #   If ib_file is empty, ibtool will return errors, but we just want to return an empty file instead of errors.
    if is_file_empty(ib_file_path):
        return temp_file_path
    
    # Run ibtool
    cltResult = subprocess.run(f"/usr/bin/ibtool --export-strings-file {temp_file_path} {ib_file_path}", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        
    if len(cltResult.stdout) > 0 or len(cltResult.stderr) > 0:
        # Log & Crash
        print(f"Error: ibtool failed. temp_file: {temp_file_path}, ib_file: {ib_file_path}, printing feedback ... \nstdout: {cltResult.stdout}\nstderr: {cltResult.stderr}")
        exit(1)
    
    # Convert to utf-8
    #   For some reason, ibtool outputs strings files as utf-16, even though strings files in Xcode are utf-8 and also git doesn't understand utf-8. Edit: I think I meant to say git doesn't understand utf-16
    convert_utf16_file_to_utf8(temp_file_path)
    
    # Return
    return temp_file_path

def read_file(file_path, encoding='utf-8'):
    
    result = ''
    with open(file_path, 'r', encoding=encoding) as temp_file:
        result = temp_file.read()
    
    return result
    

def read_tempfile(temp_file_path, remove=True):
    
    result = read_file(temp_file_path)
    
    if remove:
        os.remove(temp_file_path)
    
    return result

def write_file(file_path, content, encoding='utf-8'):
    with open(file_path, 'w', encoding=encoding) as file:
        file.write(content)

def convert_utf16_file_to_utf8(file_path):
    
    content = read_file(file_path, 'utf-16')
    write_file(file_path, content, encoding='utf-8')

def is_file_empty(file_path):
    """Check if file is empty by confirming if its size is 0 bytes.
        Also returns true if the file doesn't exist."""
    return not os.path.exists(file_path) or os.path.getsize(file_path) == 0

def clt_result_description(completed_process: subprocess.CompletedProcess) -> str:
    
    data = {
        'code': completed_process.returncode,
        'stderr': completed_process.stderr,
        'stdout': completed_process.stdout,
    }
    
    return json.dumps(data, indent=2)
    
def runCLT(command, cwd=None, exec='/bin/bash'):
    
    success_codes=[0]
    if command.startswith('git diff'): 
        success_codes.append(1) # Git diff returns 1 if there's a difference
    
    clt_result = subprocess.run(command, cwd=cwd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, executable=exec) # Not sure what `text` and `shell` does. Update: It seems that sheel is for passing the command in as a string instead of several args for several args to the clt, not sure though. We use cwd to run git commands at a differnt repo than the current workding directory
    
    assert clt_result.stderr == '' and clt_result.returncode in success_codes, f"Command \"{command}\", run in cwd \"{cwd}\"\nreturned: {clt_result_description(clt_result)}"
    
    clt_result.stdout = clt_result.stdout.strip() # The stdout sometimes has trailing newline character which we remove here.
    
    return clt_result

def run_git_command(repo_path, command):
    
    """
    Helper function to run a git command using subprocess. 
    (Credits: ChatGPT)
    
    Should probably unify this into runCLT, along with other uses of `subprocess`
    """
    proc = subprocess.Popen(['git', '-C', repo_path] + command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()

    if proc.returncode != 0:
        raise RuntimeError(f"Git command error: {stderr.decode('utf-8')}")

    return stdout.decode('utf-8')

#
# Debug Helpers
#

def get_diff_string(str1, str2, filter_unchanged_lines=True, filter_identical_files=True, show_line_numbers=True):
    
    # Generate the diff
    diff = difflib.ndiff(str1.splitlines(), str2.splitlines())
    
    is_identical = True
    for line in diff:
        if line[0] in ['-', '+']:
            is_identical = False
            break
    
    if is_identical and filter_identical_files:
        return ''

    a_ctr, b_ctr = 0, 0  # Initialize line counters

    lines = []
    for line in diff:
        mod = line[0]
        content = line[1:]
        
        a_ctr += 1 if mod in [' ', '-'] else 0 # - means line is only in a
        b_ctr += 1 if mod in [' ', '+'] else 0 # + means line is only in b

        ctr = (f"{a_ctr}  {' '*len(str(b_ctr))}" if mod == '-' else f"{b_ctr}  {' '*len(str(a_ctr))}" if mod == '+' else f"{a_ctr}->{b_ctr}") if show_line_numbers else ''

        lines.append({'mod': mod, "ctr": ctr, 'content': content})

    # Filter unchanged lines
    lines = [l for l in lines if l['mod'] in ['-', '+'] or not filter_unchanged_lines]
    
    # Join result lines into string
    result_list = [f"{l['mod']} {l['ctr']} {l['content']}" for l in lines]
    
    # Join the list into a single string
    return '\n'.join(result_list)

def indent(s, indent_spaces=2):
    return textwrap.indent(s, ' ' * indent_spaces)

#
# Find files
#

def find_files_with_extensions(exts, excluded_paths):
    
    """
    We used to use a neat glob pattern in our subprocess call `./**/*.{m,c,cpp,mm,swift}`, but that also caught python package .c files, and idk how to exclude them.
        The .c files didn't actually cause obvious problems (because they don't contain NSLocalizedString() macros anyways) but I hope this will make things a bit faster.
        (Didn't test if it's actually faster)
    """
    
    paths = []
    for ext in exts:
        pattern = f'./**/*.{ext}'
        f = glob.glob(pattern, recursive=True)
        ff = [path for path in f if not any(exc in path for exc in excluded_paths)]
        paths += ff
    
    # Return
    return paths


def find_localization_files(repo_root, website_root=None, basetypes=['IB', 'strings', 'stringsdict', 'gh-markdown', 'nuxt']):
    
    """
    Find localization files
    
    Structure of the result:
    [
        {  
            "base": "<path_to_base_localization_file>",
            "repo": git.Repo(<mac-mouse-fix|mac-mouse-fix-website>),
            "translations": {
                "path_to_translated_file1": {
                    "language_id": "<id>",
                }, 
                "path_to_translated_file2": {
                    "language_id": "<id>",
                },
                ...
            } 
        },
        ...
    ]
    
    Note: 
    - I feel like we're making this way too complicated. I can easily find all IB files in fish shell with `**/*.{xib,storyboard}`
    """
    
    # Log
    print(f'Finding translation files inside MMF repo...')
    
    # Validate
    assert repo_root[-1] != '/', "repo_root strings ends with /. Remove it."
    assert len(basetypes) > 0
    if 'nuxt' in basetypes: assert website_root
    
    # Constants
    
    markdown_dir = repo_root + '/' + "Markdown/Templates"
    exclude_paths_relative = ["Frameworks/Sparkle.framework"]
    exclude_paths = list(map(lambda exc: repo_root + '/' + exc, exclude_paths_relative))
    
    # Get repos
    mmf_repo = git.Repo(repo_root)
    website_repo = git.Repo(website_root) if website_root else None
    assert mmf_repo != None
    
    # Get result
        
    result = []
    
    # Append website basefile
    if 'nuxt' in basetypes:
        result.append({ 'base': website_root + '/' + 'locales/en-US.js', 'repo': website_repo, 'basetype': 'nuxt'})
    
    # Append markdown base_files
    if 'gh-markdown' in basetypes:
        for root, dirs, files in os.walk(markdown_dir):
            is_en_folder = 'en-US' in os.path.basename(root)
            if is_en_folder:
                files_absolute = map(lambda file: root + '/' + file, files)
                for b in files_absolute:
                    # Validate
                    _, extension = os.path.splitext(b)
                    assert extension == '.md', f'Folder at {b} contained file with extension {extension}'
                    # Append markdown file
                    result.append({ 'base': b, 'repo': mmf_repo, 'basetype': 'gh-markdown' })
        
    # Append Xcode base files 
    #   Note: We do this last because in the analysis we iterate through the `result` dict in insertion order, and analyzing the IB stuff is the slowest. So doing this last makes debugging more convenient.
    if set(['IB', 'strings', 'stringsdict']) & set(basetypes):
        for root, dirs, files in os.walk(repo_root):
            dirs[:] = [d for d in dirs if root + '/' + d not in exclude_paths]
            is_en_folder = 'en.lproj' in os.path.basename(root)
            is_base_folder = 'Base.lproj' in os.path.basename(root)
            if is_base_folder or is_en_folder:
                files_absolute = map(lambda file: root + '/' + file, files)
                for b in files_absolute:
                    # Validate
                    _, extension = os.path.splitext(b)
                    assert(is_en_folder or is_base_folder)
                    if is_en_folder: assert extension in ['.strings', '.stringsdict'], f"en.lproj folder at {b} contained file with extension {extension}"
                    if is_base_folder: assert extension in ['.xib', '.storyboard'], f"Base.lproj folder at {b} contained file with extension {extension}"
                    # Get type
                    type = 'strings' if extension == '.strings' else 'stringsdict' if extension == '.stringsdict' else 'IB'
                    # Append Xcode file
                    if type in basetypes:
                        result.append({ 'base': b, 'repo': mmf_repo, 'basetype': type })
    
    # Find translated files
    
    for e in result:
        
        base_path = e['base']
        basetype = e['basetype']
        del e['basetype']           # Not sure why we're deleting here. Might be useful for debugging.
        
        translations = {}
        
        # Get dir which contains all the translation files
        translation_root = ''
        if basetype == 'nuxt':
            translation_root = os.path.dirname(base_path) # Parent of basefile
        else:
            translation_root = os.path.dirname(os.path.dirname(base_path)) # Grandparent of basefile
        
        for root, dirs, files in os.walk(translation_root):
            
            # print(f"Finding translations in translation root {translation_root} --- root: {root}, dirs: {dirs}, files: {files}")
            
            if basetype in ['IB', 'strings', 'stringsdict']:
                
                # Don't go into folders other than `.lproj`
                dirs[:] = [d for d in dirs if '.lproj' in d]
                
                # Only process files inside `.lproj` folders
                if not '.lproj' in os.path.basename(root):
                    continue
            
            
            # Process files
            for f in files:
                
                # Get filenames and extensions
                filename, extension = os.path.splitext(os.path.basename(f))
                base_filename, base_extension = os.path.splitext(os.path.basename(base_path))
                
                # Skip unrecognized files
                if basetype in ['IB', 'strings', 'stringsdict']:
                    if extension not in ['.xib', '.storyboard', '.strings', '.stringsdict']:
                        print(f"  Skipping file {f} because it has an invalid extension. It was found while searching for translation files in {translation_root}")
                        continue
                if basetype == 'gh-markdown':
                    if extension not in ['.md']:
                        print(f"  Skipping file {f} because it has an invalid extension. It was found while searching for translation files in {translation_root}")
                        continue
                if basetype == 'nuxt':
                    if extension not in ['.js']:
                        print(f"  Skipping file {f} because it has an invalid extension. It was found while searching for translation files in {translation_root}")
                        continue
                
                # Combine info
                
                absolute_f = root + '/' + f
                filename_matches = filename == base_filename
                extension_matches = extension == base_extension
                is_base_file = absolute_f == base_path
                
                # Append
                
                do_append = False
                
                if not is_base_file:    
                    if basetype == 'nuxt':
                        if extension_matches: do_append = True
                    elif basetype == 'gh-markdown':
                        if extension_matches and filename_matches: do_append = True
                    elif basetype == 'IB':
                        if filename_matches: do_append = True
                    elif basetype == 'strings':
                        if extension_matches and filename_matches: do_append = True
                    elif basetype == 'stringsdict':
                        if extension_matches and filename_matches: do_append = True
                    else:
                        assert False
                
                if do_append:
                    
                    # Get language id
                    language_id = ''
                    if basetype == 'nuxt':
                        language_id = filename
                    else:
                        language_id, _ = os.path.splitext(os.path.basename(root)) # Parent folder name contains language_id. E.g. `de.lproj`
                    
                    # Append
                    translations[absolute_f] = { "language_id": language_id }
        
        # Append
        e['translations'] = translations
    
    return result

