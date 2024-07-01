
"""

For .swift and .c source code, Xcode automatically upldates the .xcstrings files to the source code when building the project. However we also want to use .xcstrings files for other file types (.md and .vue files). That's what this script is for.

We plan to automatically execute this script, when source files (.md and .vue) are compiled.

"""


# Imports

import tempfile
import json
import os
import argparse

import mfutils
import mflocales

#
# Constants
#

main_repo = {
    'source_paths': [ # The .md file from which we want to extract strings.
        'Markdown/Templates/Acknowledgements.md',
        'Markdown/Templates/Readme.md',
    ],
    'xcstrings_path': "Markdown/Markdown.xcstrings" # The .xcstrings file we want to update with the strings from the .md files.
}
website_repo = {
    'quotes_tool_path': "./utils/quotesTool.mjs",
    'quotes_xcstrings_path': "./locales/Quotes.xcstrings",
    'main_xcstrings_path': "./locales/Localizable.xcstrings",
}

#
# Main
#
def main():
    
    # Parse args
    parser = argparse.ArgumentParser()
    parser.add_argument('--target_repo', required=True, help='The repo that this script should work on. Should be passed automaticlally by run.py')
    args = parser.parse_args()
    target_repo = args.target_repo
    repo_name = os.path.basename(os.path.normpath(target_repo))
    
    # Extract source_files -> .stringsdata file
    if repo_name == 'mac-mouse-fix-website':
        
        # Extract strings from quotes
        # Note: 
        #   I ran into a problem where calling node failed, it was because /usr/local/bin (where node is located) was not in PATH. Restarting vscode fixed it.
        
        quotes = json.loads(mfutils.runclt(['node', website_repo['quotes_tool_path']], cwd=target_repo))
        extracted_strings = []
        for quote in quotes:
            key = quote['quoteKey']
            value = quote['englishQuote']
            comment = ' ' # Setting it to ' ' deletes any comments that have been set in the Xcode .xcstrings GUI
            if quote['originalLanguage'] != 'en':
                original_language   = mflocales.language_tag_to_language_name(quote['originalLanguage'], 'en', False)
                original_quote      = quote['originalQuote']
                comment = f'The original language of this quote is {original_language} - {original_quote}'
            
            extracted_strings.append({'comment': comment, 'key': key, 'value': value})
        
        # Call subfunc
        quotes_xcstrings_path = os.path.join(target_repo, website_repo['quotes_xcstrings_path'])
        update_xcstrings(quotes_xcstrings_path, extracted_strings)
        
        # Extract strings from .vue files
        # ...
        
        # Call subfunc
        # ...
        
    elif repo_name == 'mac-mouse-fix':
        
        # Extract strings from source_files
        extracted_strings = []
        for source_file in main_repo['source_paths']:
            
            # Load content
            content = None
            with open(source_file, 'r') as file:
                content = file.read()
            
            for key, ui_string, comment, full_match in mflocales.get_localizable_strings_from_markdown(content):
                
                # Print
                print(f"syncstrings.py: k:\n{key}\nv:\n{ui_string}\nc:\n{comment}\n-----------------------\n")
                            
                # Remove indentation from ui_string 
                #   (Otherwise translators have to manually add indentation to every indented line)
                #   (When we insert the translated strings back into the .md we have to add the indentation back in.)
                
                old_indent_level, old_indent_char = mfutils.get_indent(ui_string)
                ui_string = mfutils.set_indent(ui_string, 0, ' ')
                new_indent_level, new_indent_char = mfutils.get_indent(ui_string)
                
                if old_indent_level != new_indent_level:
                    print(f'syncstrings.py: [Changed {key} indentation from {old_indent_level}*"{old_indent_char}" -> {new_indent_level}*"{new_indent_char}"]\n')
                
                # Store result
                #   In .stringsdata format
                extracted_strings.append({'comment': comment, 'key': key, 'value': ui_string})

        # Call subfunc
        update_xcstrings(main_repo['xcstrings_path'], extracted_strings)
    
    else:
        assert False
#
# Helper
#

def update_xcstrings(xcstrings_path, extracted_strings):
    
    # Create .stringsdata file
    #   Notes on stringsTable name: 
    #       Each .xcstrings file represents one stringsTable (and should be (has to be?) named after it). 
    #       See apple docs for more info on strings tables.
    
    xcstrings_name = os.path.basename(xcstrings_path)
    strings_table_name = os.path.splitext(xcstrings_name)[0]
    stringsdata_content = {
        "source": "garbage/path.txt",
        "tables": {
            strings_table_name: extracted_strings
        },
        "version": 1
    }
    stringsdata_path = None
    with tempfile.NamedTemporaryFile(delete=False, suffix=".stringsdata", mode='w') as file: # Not sure what the 'delete' option does
        # write data
        json.dump(stringsdata_content, file, indent=2)
        # Store file path
        stringsdata_path = file.name
    
    print(f"syncstrings.py: Created .stringsdata file at: {stringsdata_path}")
    
    # Set the 'extractedState' for all strings to 'extracted_with_value'
    #   Also set the 'state' of all 'sourceLanguage' ui strings to 'new'
    #   -> If we have accidentally changed them, their state will be 'translated' 
    #       instead which will prevent xcstringstool from updating them to the new value from the source file.
    #   -> All this is necessary so that xcstringstool updates everything (I think)
    
    xcstrings_obj = json.loads(mfutils.read_file(xcstrings_path))
    source_language = xcstrings_obj['sourceLanguage']
    assert source_language == 'en'
    for key, info in xcstrings_obj['strings'].items():
        info['extractionState'] = 'extracted_with_value'
        if 'localizations' in info.keys() and source_language in info['localizations'].keys():
            info['localizations'][source_language]['stringUnit']['state'] = 'new'
        else:
            pass
            # assert False
        
    mfutils.write_file(xcstrings_path, json.dumps(xcstrings_obj, indent=2))
    print(f"syncstrings.py: Set the extractionState of all strings to 'extracted_with_value'")
        
    # Use xcstringstool to sync the .xcstrings file with the .stringsdata
    developer_dir = mfutils.runclt("xcode-select --print-path")
    stringstool_path = os.path.join(developer_dir, 'usr/bin/xcstringstool')
    result = mfutils.runclt(f"{stringstool_path} sync {xcstrings_path} --stringsdata {stringsdata_path}")
    print(f"syncstrings.py: ran xcstringstool to update {xcstrings_path} Result: {result}")
    
    # Set the 'extractedState' for all strings to 'manual'
    #   Otherwise Xcode won't export them and also delete all of them or give them the 'Stale' state
    #   (We leave strings 'stale' which this analysis determined to be stale)
    xcstrings_obj = json.loads(mfutils.read_file(xcstrings_path))
    for key, info in xcstrings_obj['strings'].items():
        if info['extractionState'] == 'stale':
            pass
        else:
            info['extractionState'] = 'manual'

    mfutils.write_file(xcstrings_path, json.dumps(xcstrings_obj, indent=2))
    print(f"syncstrings.py: Set the extractionState of all strings to 'manual'")

#
# Call main
#
if __name__ == "__main__":
    main()
