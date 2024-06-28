
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
    'Markdown/acknowledgements_skeleton.md',
    'Markdown/readme_skeleton.md',
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
        
        # Extract translatable strings with inline syntax
        # Notes:
        #   - Use https://regex101.com
        
        print("Extracting inline strings...")
        
        """
        The inline sytax looks like this:  
        
        
        bla blah {{🙌 Acknowledgements||acknowledgements.title||This is the title for the acknowledgements document!}}
        
        blubb
        
        bli blubb {{😔 Roasting of Enemies||roast.title||This is the title for the roasting of enemies document!}} blah
        """
        inline_regex = r"\{\{(.*?)\|\|(.*?)\|\|(.*?)\}\}" # r makes it so \ is treated as a literal character and so we don't have to double escape everything
        inline_matches = re.finditer(inline_regex, content)
        
        # Extract translatable strings with block syntax
        
        """
        The syntax for block strings looks like this:
        
        ```
        key: acknowledgements.body
        ```
        Big thanks to everyone using Mac Mouse Fix.

        I want to especially thank the people and projects named in this document.
        ```
        comment: This is the intro for the acknowledgements document
        ```
        
        Not a translatable string:
        ```
        nope
        ```
        
                ```
        key: acknowledgements.booty
        ```
            hello 

        ```
        comment: Moar stufff
        ```
        
        """
        
        block_regex = r"```\n\s*?key:\s*(.*?)\s*\n\s*?```\n\s*(^.*?$)\s*```\n\s*?comment:\s*?(.*?)\s*\n\s*?```"      #r"```\n\s*?key:\s*(.*?)\s*\n\s*?```\n(.*)\n\s*?```\n\s*?comment:\s*(.*?)\s*\n\s*?```"
        block_matches = re.finditer(block_regex, content, re.DOTALL | re.MULTILINE)
        
        # Assemble parsed_strings list
        parsed_strings = []
        for match in inline_matches:
            ui_string, key, comment = match.groups()
            parsed_strings.append({'comment': comment, 'key': key, 'value': ui_string})
        for match in block_matches:
            key, ui_string, comment = match.groups()
            parsed_strings.append({'comment': comment, 'key': key, 'value': ui_string})
        
        for r in parsed_strings:
            
            key = r['key']
            ui_string = r['value']
            comment = r['comment']
            
            # Print
            print(f"k:\n{key}\nv:\n{ui_string}\nc:\n{comment}\n-----------------------\n")
            
            # Validate
            assert ' ' not in key, f'key contains space: {key}' # I don't think string keys are supposed to contain spaces inside the Xcode toolchain stuff
            assert len(key) > 0 # We need a key to parse this
            assert len(ui_string) > 0 # English ui strings are defined directly in the markdown file - don't think this should be empty
            for str in [ui_string, key, comment]:
                assert r'}}' not in str # Protect against matching past the first occurrence of }}
                assert r'||' not in str # Protect against ? - this is weird
                assert r'{{' not in str # Protect against ? - this is also weird
        
        # Create .stringsdata file
        
        stringsdata_content = {
            "source": "garbage/path.md",
            "tables": {
                strings_table_name: parsed_strings
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
        
        # Find XCStringsTool
        developer_dir = shared.runCLT("xcode-select --print-path").stdout
        stringstool_path = os.path.join(developer_dir, 'usr/bin/xcstringstool')
        
        # Update the .xcstrings file using the .stringdata
        result = shared.runCLT(f"{stringstool_path} sync {xcstrings_path} --stringsdata {stringsdata_path}")
        
        print(f"ran XCStringsTool to update {xcstrings_path} Result: {shared.clt_result_description(result)}")

        

#
# Call main
#
if __name__ == "__main__":
    main()
