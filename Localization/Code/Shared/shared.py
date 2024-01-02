#
# Imports
#

import tempfile
import difflib
import subprocess
import os
import re


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
    
    
    # Define regex
    
    """
      Used to get keys and values from strings files. Designed to work on Xcode .strings files and on the .js strings files used on the MMF website. (Won't work on `.stringsdict`` files, those are xml)
      See https://regex101.com
    
    Some test strings:    
    
'quote-"source".,//youtubeComment':  "**{ name }** in// einem YouTube,-KommentarIS_OK", // ! omgg !!IS_OK ,that's so 
+  'quote-source.youtubeComment':  "**{ name }** in' einem'` YouTube`-Kommentar", // IS_OK
    'quote-source.youtubeComment':  "**{ name }** in einem YouTube-Kommentar", /* !IS_OK */
-  "quote-"source".,//youtubeComment" =  '**{ name }** in// einem YouTube,-KommentarIS_OK'; // ! omgg !!IS_OK ,that's so 
    """
    
    strings_file_regex = re.compile(r'^(\+?\-?)\s*[\'\"](.+)[\'\"]\s*[=:]\s*[\'\"](.*)[\'\"][,;].*?(\/.*?(!+IS_OK).*)?$', re.MULTILINE)
    
    # Find matches
    matches = strings_file_regex.finditer(text)
    
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

def read_tempfile(temp_file_path, remove=True):
    
    result = ''
    
    with open(temp_file_path, 'r', encoding='utf-8') as temp_file:
        result = temp_file.read()
    
    if remove:
        os.remove(temp_file_path)
    
    return result

def convert_utf16_file_to_utf8(file_path):
    
    content = ''
    
    # Read from UTF-16 file
    with open(file_path, 'r', encoding='utf-16') as file:
        content = file.read()

    # Write back to the same file in UTF-8
    with open(file_path, 'w', encoding='utf-8') as file:
        file.write(content)

def is_file_empty(file_path):
    """Check if file is empty by confirming if its size is 0 bytes.
        Also returns true if the file doesn't exist."""
    return not os.path.exists(file_path) or os.path.getsize(file_path) == 0

def runCLT(command, cwd=None):
    
    success_codes=[0]
    if command.startswith('git diff'): 
        success_codes.append(1) # Git diff returns 1 if there's a difference
    
    clt_result = subprocess.run(command, cwd=cwd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) # Not sure what `text` and `shell` does. We use cwd to run git commands at a differnt repo than the current workding directory
    
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

def get_diff_string(str1, str2, filter_unchanged_lines=True):
    
    # Generate the diff
    diff = difflib.ndiff(str1.splitlines(), str2.splitlines())

    # Accumulate the diff output in a list & filter unchanged lines
    diff_list = [line for line in diff if not filter_unchanged_lines or line.startswith('+ ') or line.startswith('- ')]
    
    # Join the list into a single string
    return '\n'.join(diff_list)