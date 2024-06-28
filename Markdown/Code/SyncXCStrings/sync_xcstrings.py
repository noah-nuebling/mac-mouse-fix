
# Imports

import re
import tempfile
import json
import shared # The 'shared' module was originally part fo the 'Localization' Python scripts, but now we're using it here, too. Should probably move 'shared.py' to a differnent place.
import os

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
    
    for source_file in source_paths:
        
        # Load content
        content = None
        with open(source_file, 'r') as file:
            content = file.read()
        
        # Extract localizable strings from content
        
        extracted_srings = []
        
        for key, ui_string, comment, full_match in shared.get_localizable_strings_from_markdown(content):
            
            # Print
            print(f"k:\n{key}\nv:\n{ui_string}\nc:\n{comment}\n-----------------------\n")
                        
            # Remove indentation from ui_string 
            #   (Otherwise translators have to manually add indentation to every indented line)
            #   (When we insert the translated strings back into the .md we have to add the indentation back in.)
            
            old_indent_level, old_indent_char = shared.get_indent(ui_string)
            ui_string = shared.set_indent(ui_string, 0, ' ')
            new_indent_level, new_indent_char = shared.get_indent(ui_string)
            
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
        
        # sync the .xcstrings file with the .stringsdata using xcstringstool
        
        developer_dir = shared.runCLT("xcode-select --print-path").stdout
        stringstool_path = os.path.join(developer_dir, 'usr/bin/xcstringstool')
        result = shared.runCLT(f"{stringstool_path} sync {xcstrings_path} --stringsdata {stringsdata_path}")
        
        print(f"ran xcstringstool to update {xcstrings_path} Result: {shared.clt_result_description(result)}")
        

#
# Call main
#
if __name__ == "__main__":
    main()
