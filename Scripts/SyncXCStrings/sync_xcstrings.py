
"""

For .swift and .c source code, Xcode automatically upldates the .xcstrings files to the source code when building the project. However we also want to use .xcstrings files for other file types (.md and .vue files). That's what this script is for.

We plan to automatically execute this script, when source files (.md and .vue) are compiled.

"""


# Imports

import tempfile
import json
import os

import mfutils
import mflocales

#
# Constants
#
source_paths = [ # The .md file from which we want to extract strings.
    'Markdown/Templates/Acknowledgements.md',
    'Markdown/Templates/Readme.md',
]

strings_table_name = "Markdown" # Each .xcstrings file represents one stringsTable (and should probably be named after it). This is the name we use for the table of strings which were extracted from Markdown. See apple docs for more info on strings tables.

xcstrings_path = "Markdown/Markdown.xcstrings" # The .xcstrings file we want to update with the strings from the .md files. Should be named after the strings_table

#
# Main
#
def main():
    
    
    # Extract localizable strings from content
    
    extracted_srings = []
    
    for source_file in source_paths:
        
        # Load content
        content = None
        with open(source_file, 'r') as file:
            content = file.read()
        
        for key, ui_string, comment, full_match in mflocales.get_localizable_strings_from_markdown(content):
            
            # Print
            print(f"k:\n{key}\nv:\n{ui_string}\nc:\n{comment}\n-----------------------\n")
                        
            # Remove indentation from ui_string 
            #   (Otherwise translators have to manually add indentation to every indented line)
            #   (When we insert the translated strings back into the .md we have to add the indentation back in.)
            
            old_indent_level, old_indent_char = mfutils.get_indent(ui_string)
            ui_string = mfutils.set_indent(ui_string, 0, ' ')
            new_indent_level, new_indent_char = mfutils.get_indent(ui_string)
            
            if old_indent_level != new_indent_level:
                print(f'[Changed {key} indentation from {old_indent_level}*"{old_indent_char}" -> {new_indent_level}*"{new_indent_char}"]\n')
            
            # Store result
            #   In .stringsdata format
            extracted_srings.append({'comment': comment, 'key': key, 'value': ui_string})
        
    # Create .stringsdata file
    
    stringsdata_content = {
        "source": "garbage/path.md",
        "tables": {
            strings_table_name: extracted_srings
        },
        "version": 1
    }
    stringsdata_path = None
    with tempfile.NamedTemporaryFile(delete=False, suffix=".stringsdata", mode='w') as file: # Not sure what the 'delete' option does
        # write data
        json.dump(stringsdata_content, file, indent=2)
        # Store file path
        stringsdata_path = file.name
    
    print(f"Created .stringsdata file at: {stringsdata_path}")
    
    # Set the 'extractedState' for all strings to 'extracted_with_value' 
    #   Also set the 'state' of all 'sourceLanguage' ui strings to 'new'
    #   -> If we have accidentally changed them, their state will be 'translated' 
    #       instead which will prevent xcstringstool from updating them to the new value from the markdown file.
    #   -> All this is necessary so that xcstringstool updates everything (I think)
    
    xcstrings_obj = json.loads(mfutils.read_file(xcstrings_path))
    source_language = xcstrings_obj['sourceLanguage']
    assert source_language == 'en'
    for key, info in xcstrings_obj['strings'].items():
        info['extractionState'] = 'extracted_with_value'
        info['localizations'][source_language]['stringUnit']['state'] = 'new'
        
    mfutils.write_file(xcstrings_path, json.dumps(xcstrings_obj, indent=2))
    print(f"Set the extractionState of all strings to 'extracted_with_value'")
        
    # Use xcstringstool to sync the .xcstrings file with the .stringsdata
    developer_dir = mfutils.runCLT("xcode-select --print-path").stdout
    stringstool_path = os.path.join(developer_dir, 'usr/bin/xcstringstool')
    result = mfutils.runCLT(f"{stringstool_path} sync {xcstrings_path} --stringsdata {stringsdata_path}")
    print(f"ran xcstringstool to update {xcstrings_path} Result: {mfutils.clt_result_description(result)}")
    
    # Set the 'extractedState' for all strings to 'manual' 
    #  Otherwise Xcode won't export them and also delete all of them or give them the 'Stale' state
    xcstrings_obj = json.loads(mfutils.read_file(xcstrings_path))
    for key, info in xcstrings_obj['strings'].items():
        info['extractionState'] = 'manual'
    mfutils.write_file(xcstrings_path, json.dumps(xcstrings_obj, indent=2))
    print(f"Set the extractionState of all strings to 'manual'")
    
#
# Call main
#
if __name__ == "__main__":
    main()
