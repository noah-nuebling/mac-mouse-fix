
#
# Native imports
#

import sys
import os
from pprint import pprint
import argparse

#
# Import functions from ../Shared folder
#

code_dir = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
if code_dir not in sys.path:
    sys.path.append(code_dir)
from Shared import shared

#
# Constants
#

temp_folder = './update_comments_temp'

#
# Main
#

def main():
    
    # Args
    parser = argparse.ArgumentParser()
    parser.add_argument('--wet_run', required=False, action='store_true', help="Provide this arg to actually modify files. Otherwise it will just log what it would do.", default=False)
    args = parser.parse_args()
    
    # Constants & stuff
    repo_root = os.getcwd()
    assert os.path.basename(repo_root) == 'mac-mouse-fix', "Run this script from the 'mac-mouse-fix' repo folder."
    
    # Create temp dir
    shared.runCLT(f"mkdir -p {temp_folder}")
    
    # Find files
    ib_files = shared.find_localization_files(repo_root, None, ['IB'])
    strings_files = shared.find_localization_files(repo_root, None, ['strings'])
    assert len(strings_files) == 1, "There should only be one base .strings file - Localizable.strings"
    
    # Update .strings files
    update_ib_strings(ib_files, args.wet_run)
    update_source_code_strings(strings_files[0], args.wet_run)
    
    # Debug
    # pprint(ib_files)
    # pprint(strings_files)
    
    # Clean up
    shared.runCLT(f"rm -R ./{temp_folder}")
    

#
# Update comments in .xib and .storyboard file translations
#

def update_ib_strings(files, wet_run):
    """
    Update .strings files to match .xib/.storyboard files which they translate
    
    """
    
    for file_dict in files:
        
        base_file_path = file_dict['base']
        generated_path = shared.extract_strings_from_IB_file_to_temp_file(base_file_path)
        generated_content = shared.read_tempfile(generated_path)
        
        modss = []
        
        for translation_path in file_dict['translations'].keys():
        
            
            content = shared.read_file(translation_path, 'utf-8')
            
            new_content, mods = update_strings_file_content(content, generated_content)
            
            if wet_run:
                shared.write_file(translation_path, new_content)
            
            modss.append({'path': translation_path, 'mods': mods})
        
        log_modifications(modss)
            

#
# Update comments in Localizable.strings files
#

def update_source_code_strings(files, wet_run):
    
    """
    Update .strings files to match source code files which they translate
    Discussion: 
    - In update_ib_comments we don't update development language files - because there are none, since development language strings are directly inside the ib files.
      But in this function, we also update en.lproj/Localizable.strings. Maybe we should've specified development language values directly in the source code using `NSLocalizedStringWithDefaultValue` instead of inside en.lproj. That way we wouldn't need en.lproj at all.
      Not sure anymore why we chose to do it with en.lproj instead of all source code for English. But either way, I don't think it's worth it to change now.
    Note:
    """
    
    # print(shared.runCLT(f"pwd; echo ./**/*.{{m,c,cpp,mm,swift}}", exec='/bin/zsh').stdout)
    
    # return
    shared.runCLT(f"extractLocStrings ./**/*.{{m,c,cpp,mm,swift}} -SwiftUI -o ./{temp_folder}", exec='/bin/zsh')
    generated_path = f"{temp_folder}/Localizable.strings"
    generated_content = shared.read_file(generated_path, 'utf-16')
    
    strings_files_flat = []
    strings_files_flat.append(files['base'])
    strings_files_flat += files['translations'].keys()
    
    modss = []
    
    for path in strings_files_flat:
        
        content = shared.read_file(path, 'utf-8')
        
        new_content, mods = update_strings_file_content(content, generated_content)
        
        if wet_run:
            shared.write_file(path, new_content)
        
        modss.append({'path': path, 'mods': mods})
    
    log_modifications(modss)
        

#
# Debug helper
#

def log_modifications(modss):
    
    result = ''
    
    for mods in modss:
        
        result += f"\n\n{mods['path']} was modified:"
        
        for mod in sorted(mods['mods'], key=lambda x: x['modtype'], reverse=True):
            
            key = mod['key']
            modtype = mod['modtype']
            if modtype == 'comment':
                
                b = mod['before'].strip()
                a = mod['after'].strip()
                
                if a == b:
                    result += f"\n\n    {key}'s comment whitespace changed"    
                else:
                    a = shared.indent(a, 8)
                    b = shared.indent(b, 8)
                    
                    result += f"\n\n    {key} comment changed:\n{b}\n        ->\n{a}"
                
            elif modtype == 'insert':
                value = shared.indent(mod['value'], 8)
                result += f"\n\n    {key} was inserted:\n{value}"
                
            else: assert False
    
    print(result)
            
    
    
#
# String parse & modify
#

def update_strings_file_content(content, generated_content):
    
    """
    At the time of writing:
    - Copy over all comments from `generated_content` to `content`
    - Insert kv-pair + comment from `generated_content` into `content` - if the kv-pair is not found in `content`
    - Reorder kv-pairs in `content` to match `generated_content`
    """
    
    # Parse both contents
    parse = parse_strings_file_content(content)
    generated_parse = parse_strings_file_content(generated_content, remove_value=True) # `extractLocStrings` sets all values to the key for some reason, so we remove them.
    
    # Record modifications for diagnositics
    mods = []
    
    # Replace comments 
    #   (And insert missing kv-pairs, too, to be able to add comments)
    for key in generated_parse.keys():
        
        is_missing = key not in parse
        
        p = None if is_missing else parse[key]
        g = generated_parse[key]
        
        if is_missing:
            
            parse[key] = g
            mods.append({'key': key, 'modtype': 'insert', 'value': g['comment'] + g['line']})
            
        else:
            if p['comment'] != g['comment']:
                mods.append({'key': key, 'modtype': 'comment', 'before': p['comment'], 'after': g['comment']})
                p['comment'] = g['comment']
    
    # Reassemple parse into updated content
    
    new_content = ''

    # Attach kv-pairs that also occur in generated_content
    #   Python iterates over dicts in insertion order. Therefore, this should synchronize the order of kv-pairs in the new_content with the generated_content
    for k in generated_parse.keys():
        new_content += parse[k]['comment']
        new_content += parse[k]['line']
    
    # Attach unused kv-pairs at the end. 
    #   Why not just delete them?
    superfluous_keys = [k for k in parse.keys() if k not in generated_parse.keys()]
    for k in superfluous_keys:
        new_content += parse[k]['comment']
        new_content += parse[k]['line']
    
    # Return
    return new_content, mods
    
    

def parse_strings_file_content(content, remove_value=False):
    
    result = {}
    
    regex = shared.strings_file_regex()
    
    last_key = ''
    acc_comment = ''
    
    for i, line in enumerate(content.splitlines(True)):
        
        match = regex.match(line)
        
        if match:
            
            key = match.group(2)
            if remove_value:
                value_start = match.start(3)
                value_end = match.end(3)
                result_line = line[:value_start] + line[value_end:]
            else:
                result_line = line
            
            result[key] = { "line": result_line, "comment": acc_comment }
            acc_comment = ''
            
            last_key = key
        else:
            acc_comment += line
    
    post_comment = acc_comment
    result[last_key]['post_comment'] = post_comment
    assert len(post_comment.strip()) == 0, f"There's content under the last key {last_key}. Don't know what to do with that. Pls remove."
    
    return result
    
    
    
            
    
    
    




#
# Call main
#

if __name__ == "__main__": 
    main()
    
    
