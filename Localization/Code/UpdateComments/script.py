
#
# Native imports
#

import sys
import os
from pprint import pprint

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
    
    # Constants & stuff
    repo_root = os.getcwd()
    assert os.path.basename(repo_root) == 'mac-mouse-fix', "Run this script from the 'mac-mouse-fix' repo folder."
    
    # Create temp dir
    shared.runCLT(f"mkdir -p {temp_folder}")
    
    # Find files
    ib_files = shared.find_localization_files(repo_root, None, ['IB'])
    strings_files = shared.find_localization_files(repo_root, None, ['strings'])
    assert len(strings_files) == 1, "There should only be one base .strings file - Localizable.strings"
    
    # Update comments
    update_ib_comments(ib_files, repo_root)
    update_source_code_comments(strings_files[0], repo_root)
    
    # Debug
    pprint(ib_files)
    pprint(strings_files)
    
    # Clean up
    shared.runCLT(f"rm -R ./{temp_folder}")
    

#
# Update comments in .xib and .storyboard file translations
#

def update_ib_comments(files, repo_root):
    """
    Update the comments inside .strings files to match .xib/.storyboard files which they translate
    
    """
    
    pass


#
# Update comments in Localizable.strings files
#

def update_source_code_comments(files, repo_root):
    
    """
    Update comments inside .strings files to match source code files which they translate
    Discussion: 
    - In update_ib_comments we don't update development language files - because there are none, since development language strings are directly inside the ib files.
      But in this function, we also update en.lproj/Localizable.strings. Maybe we should've specified development language values directly in the source code using `NSLocalizedStringWithDefaultValue` instead of inside en.lproj. That way we wouldn't need en.lproj at all.
      Not sure anymore why we chose to do it with en.lproj instead of all source code for English. But either way, I don't think it's worth it to change now.
    """
    
    # print(shared.runCLT(f"pwd; echo ./**/*.{{m,c,cpp,mm,swift}}", exec='/bin/zsh').stdout)
    
    # return
    shared.runCLT(f"extractLocStrings ./**/*.{{m,c,cpp,mm,swift}} -SwiftUI -o ./{temp_folder}", exec='/bin/zsh')
    generated_path = f"{temp_folder}/Localizable.strings"
    generated_content = shared.read_file(generated_path, 'utf-16')
    
    strings_files_flat = []
    strings_files_flat.append(files['base'])
    strings_files_flat += files['translations'].keys()
    
    for path in strings_files_flat:
        
        content = shared.read_file(path, 'utf-8')
        
        new_content = update_strings_file_content(content, generated_content)
        
        # shared.write_file(path, new_content)
        # print(f"Diff: {shared.get_diff_string(content, new_content)}")
        print(f"Gen: {generated_content}")
        print(f"Diff: {content}\n\n )")
        
        
def update_strings_file_content(content, generated_content):
    """
    Copies over comments from generated_content to content
    """
    
    




#
# Call main
#

if __name__ == "__main__": 
    main()