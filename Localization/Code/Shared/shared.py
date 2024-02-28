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
    #   For some reason, ibtool outputs strings files as utf-16, even though strings files in Xcode are utf-8 and also git doesn't understand utf-8.
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

def runCLT(command, cwd=None, exec='/bin/bash'):
    
    success_codes=[0]
    if command.startswith('git diff'): 
        success_codes.append(1) # Git diff returns 1 if there's a difference
    
    clt_result = subprocess.run(command, cwd=cwd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, executable=exec) # Not sure what `text` and `shell` does. We use cwd to run git commands at a differnt repo than the current workding directory
    
    assert clt_result.stderr == '' and clt_result.returncode in success_codes, f"Command \"{command}\", run in cwd \"{cwd}\"\n--- stderr:\n{clt_result.stderr}\n--- code:\n{clt_result.returncode}\n--- stdout:\n{clt_result.stdout}"
    
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
