
#
# Imports
# 

import os
from pprint import pprint
import git
import re
import subprocess
import tempfile

#
# Constants
#

#
# Main
#

def main():
    
    # Get info
    repo_root = os.getcwd()

    # Log
    print(f'Finding translation files inside MMF repo...')

    # Find localization files in MMF repo
    files = find_localization_files_in_mmf_repo(repo_root)
    
    
    
    # Analyze localization files
    
    # Log
    print(f'Analyzing localization files...')
    
    # Get 'outdating commits'
    #   This is a more primitive method than analyzing the changes to translation keys. Should only be relevant for files that don't have translation keys
    
    print(f'  Analyzing outdating commits...')
    git_repo = git.Repo(repo_root)
    for file_dict in files:
        base_file = file_dict['base']
        
        for translation_file, translation_dict in file_dict['translations'].items():
            
            
            translation_commit_iterator = git_repo.iter_commits(paths=translation_file, **{'max-count': 1} ) # max-count is passed along to `git rev-list` command-line-arg
            last_translation_commit = next(translation_commit_iterator)
            
            outdating_commits = []
            
            base_commit_iterator = git_repo.iter_commits(paths=base_file)
            
            for base_commit in base_commit_iterator:
                if not is_predecessor(base_commit, last_translation_commit):
                    outdating_commits.append(base_commit)
                else:
                    break
            
                
            if len(outdating_commits) > 0:
                translation_dict['outdating_commits'] = outdating_commits
    
    
    # Log
    print(f'  Analyzing changes to translation keys...')
    
    # Analyze changes to translation keys
    for file_dict in files:
        
        # Iterate through base files:
        
        # Get info
        base_file_path = file_dict['base']
        
        # Log
        print(f'    Processing base translation at {base_file_path}...')
        
        # Find basefile keys
        base_keys_and_values = find_translation_keys_and_values_in_file(file_dict['base'])
        if base_keys_and_values == None: continue
        base_keys = set(base_keys_and_values.keys())
        
        # DEBUG
        latest_base_changes = None
        _, file_type = os.path.splitext(base_file_path)
        if file_type == '.xib' or file_type == '.storyboard':
            pass
        else:
            # For each key in the base file, get the commit, when it last changed  
            latest_base_changes = get_latest_change_for_translation_keys(base_keys, base_file_path, git_repo)
        
        for translation_file_path, translation_dict in file_dict['translations'].items():
            
            # Log
            print(f'      Processing translation of {os.path.basename(base_file_path)} at {translation_file_path}...')
            print(f'        Find translation keys and values...')
            
            # Find translation file keys
            translation_keys_and_values = find_translation_keys_and_values_in_file(translation_file_path)
            translation_keys = set(translation_keys_and_values.keys())
            
            print(f'        Check missing/superfluous keys...')
            
            # Do set operations
            missing_keys = base_keys.difference(translation_keys)
            superfluous_keys = translation_keys.difference(base_keys)
            common_keys = base_keys.intersection(translation_keys)
            
            # Attach set operation data
            translation_dict['missing_keys'] = missing_keys
            translation_dict['superfluous_keys'] = superfluous_keys
            
            # DEBUG
            _, file_type = os.path.splitext(base_file_path)
            if file_type == '.xib' or file_type == '.storyboard':
                continue
            
            # Log
            print(f'        Analyze when keys last changed...')
            
            # Check common keys if they are outdated.
            
            # For each key, get the commit when it last changed
            latest_translation_changes = get_latest_change_for_translation_keys(common_keys, translation_file_path, git_repo)
            
            # if 'capture-toast.body' in common_keys:  # 'Localization/de.lproj/Localizable.strings' in translation_file_path:
            #     print(f"latest_base_changes: {base_file_path}, changes: {latest_base_changes}")
            #     print(f"translated_changes: {translation_file_path}, changes: {latest_translation_changes}")
            
            # Log
            print(f'        Check if last modification was before base for each key ...')
            
            # Compare time of latest change for each key between base file and translation file
            for k in common_keys:
                
                # if k == 'capture-toast.body':
                #     pprint(f"translation_dict: {translation_dict}")
                #     break
                
                base_commit = latest_base_changes[k]
                translation_commit = latest_translation_changes[k]
                
                base_commit_is_predecessor = is_predecessor(base_commit, translation_commit)
                
                if not base_commit_is_predecessor:
                    translation_dict.setdefault('outdated_keys', {})[k] = { 'latest_base_change': base_commit, 'latest_translation_change': translation_commit }    
    
    pprint(files)
        

    
def is_predecessor(potentialPredecessorCommit, commit):
    
    # Check which commit is 'earlier'. Works kind of like potentialPredecessorCommit <= commit (returns true for equality)
    # Not totally sure what we're doing here. 
    #   - First, we were checking for ancestry with `git merge-base``, but that slowed the whole script down a lot (maybe we could've alleviated that by changing runCLT? We have some weird options there.) (We also tried `rev-list --is-ancestor`, but it didn't help.)
    #   - Then we updated to just comparing the commit date. I think it might make less sense than checking ancestry, and might lead to wrong results, maybe? But currently it seems to work okay and is faster. 
    #   - Not sure if `committed_date` or `authored_date` is better. Both seem to give the same results atm.
        
    return potentialPredecessorCommit.committed_date <= commit.committed_date
    # return runCLT(f"git rev-list --is-ancestor {potentialPredecessorCommit.hexsha} {commit.hexsha}").returncode == 0
    # return runCLT(f"git merge-base --is-ancestor {potentialPredecessorCommit.hexsha} {commit.hexsha}").returncode == 0

def runCLT(command):
    clt_result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) # Not sure what `text` and `shell` does.
    return clt_result



def get_latest_change_for_translation_keys(wanted_keys, file_path, git_repo):
    
    wanted_keys = wanted_keys.copy()
    latest_changes = dict()
    
    for i, commit in enumerate(git_repo.iter_commits(paths=file_path)):
        
        # if 'Localization/de.lproj/Localizable.strings' in file_path:
        #     print(f"latest de changes: {latest_changes}, {list(git_repo.iter_commits(paths=file_path))}")
        
        # Debug
        # print(f"Iteration {i}. wanted_keys: {wanted_keys}")
        
        # Break      
        if len(wanted_keys) == 0:
            break
        
        # Extract info
        commit_hash = commit.hexsha
        commit_date = commit.committed_date
        _, file_type = os.path.splitext(file_path)
        
        # Run git command 
        # - For getting additions and deletions of the commit compared to its parent
        # - I tried to do this with gitpython but nothing worked, maybe I should stop using it altogether?
        diff_string = runCLT(f"git diff -U0 {commit_hash}^..{commit_hash} -- {file_path}").stdout

        # Parse
        # print(f"finding keys and valis in {file_path}, {commit_hash}, {commit_date} ...")
        keys_and_values = find_translation_keys_and_values(diff_string, file_type)
        
        for key, changes in keys_and_values.items():
            if key in latest_changes:
                continue
            if key not in wanted_keys:
                continue
            if changes.get('added', None) != changes.get('deleted', None):
                latest_changes[key] = commit
                wanted_keys.remove(key)
        
    return latest_changes

def find_translation_keys_and_values_in_file(file_path):
    
    # Read file content
    text = ''
    with open(file_path, 'r') as file:
        text = file.read()

    # Get extension
    _, file_type = os.path.splitext(file_path)
    
    # Call core
    if file_type == '.xib' or file_type == '.storyboard':
        result = find_translation_keys_and_values_in_IB_file(file_path)
    else: 
        result = find_translation_keys_and_values(text, file_type)
    
    # Return
    return result


def find_translation_keys_and_values_in_IB_file(file_path):
        
    strings_text = ''
    temp_file_path = ''
    
    with tempfile.NamedTemporaryFile(delete=False) as temp_file:
        temp_file_path = temp_file.name
    
    cltResult = subprocess.run(f"/usr/bin/ibtool --export-strings-file {temp_file.name} {file_path}", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if len(cltResult.stdout) > 0 or len(cltResult.stderr) > 0:
        print(f"Error: ibtool failed. Printing feedback ... \nstdout: {cltResult.stdout}\nstderr: {cltResult.stderr}")
        exit(1)
    
    with open(temp_file_path, 'r', encoding='utf-16') as temp_file:
        strings_text = temp_file.read()
    
    os.remove(temp_file_path)
    
    keys_and_values = find_translation_keys_and_values(strings_text, '.strings')
    
    return keys_and_values
        
        
def find_translation_keys_and_values(text, file_type):

    """
    Extract translation keys and values from text.
    Structure of result:
    {
        <translation_key>: {
            added<?>: <translation_value>,
            deleted<?>: <translation_value>,
            value<?>: <translation_value>,
        }
        <translation_key>: {
            ...
        },
        ... 
    }

    ... where <?> means that the key is optional. 
        If the input text is a git diff text with - and + at the start of lines, then the result with contain `added` and `deleted` keys, otherwise, the result will contain `value` keys.
    """
    
    if file_type == '.strings':
        
        # Strings file regex:
        #   Used to get keys and values from strings files. Designed to work on Xcode .strings files and on the .js strings files used on the MMF website. (Won't work on `.stringsdict`` files, those are xml)
        #   See https://regex101.com
        strings_file_regex = re.compile(r'^(\+?\-?)\s*[\'\"]([^\'\"]+)[\'\"]\s*[=:]\s*[\'\"]([^\'\"]*)[\'\"]', re.MULTILINE)
        
        # Find matches
        matches = strings_file_regex.finditer(text)
        
        # Parse matches
        
        result = dict()
        for match in matches:
            git_line_diff = match.group(1)
            translation_key = match.group(2)
            translation_value = match.group(3)
            
            k = 'added' if git_line_diff == '+' else 'deleted' if git_line_diff == '-' else 'value'
            result.setdefault(translation_key, {})[k] = translation_value
            
            # if translation_key == 'capture-toast.body':
                # print(f"{git_line_diff} value: {translation_value} isNone: {translation_value is None}") # /Users/Noah/Desktop/mmf-stuff/mac-mouse-fix/Localization/de.lproj/Localizable.strings
                # print(f"result: {result}")
                
        return result
    elif file_type == '.xib' or file_type == '.storyboard':
        # assert False
        return None
    
    elif file_type == '.stringsdict':
        return None
    elif file_type == '.md':
        return None
    else:
        assert False, f"translation key/value finder encountered unknown file type: {file_type}"

def find_localization_files_in_mmf_repo(repo_root):
    
    # Find localization files
    #
    #   Structure of the result:
    #   [
    #       {  
    #           base: path_to_base_localization_file, 
    #           basetype: "<IB | strings | markdown>"", 
    #           translations: {
    #               path_to_translated_file1: {}, 
    #               path_to_translated_file2: {}, 
    #               ...
    #           } 
    #       },
    #       ...
    #   ]
    
    # Constants
    
    markdown_dir = repo_root + '/' + "Markdown/Templates"
    exclude_paths_relative = ["Frameworks/Sparkle.framework"]
    exclude_paths = list(map(lambda exc: repo_root + '/' + exc, exclude_paths_relative))
    
    # Get result
        
    result = []
    
    # Find base_files
    
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
                if is_en_folder: assert extension in ['.strings', '.stringsdict'], f"en.lproj folder contained file with extension {extension}"
                if is_base_folder: assert extension in ['.xib', '.storyboard'], f"Base.lproj folder contained file with extension {extension}"
                # Get type
                type = 'strings' if is_en_folder else 'IB'
                # Append
                result.append({ 'base': b, 'basetype': type })
    
    for root, dirs, files in os.walk(markdown_dir):
        is_en_folder = 'en-US' in os.path.basename(root)
        if is_en_folder:
            files_absolute = map(lambda file: root + '/' + file, files)
            for b in files_absolute:
                # Append
                result.append({ 'base': b, 'basetype': 'markdown' })
    
    # Find translated files
    
    for e in result:
        
        base_path = e['base']
        basetype = e['basetype']
        
        translations = {}
        
        # Get grandparent dir of the base file, which contains all the translation files
        grandpa = os.path.dirname(os.path.dirname(base_path))
        
        for root, dirs, files in os.walk(grandpa):
            
            if basetype == 'IB' or basetype == 'strings':
                
                # Don't go into .lproj folders
                dirs[:] = [d for d in dirs if '.lproj' in d]
                
                # Only process files inside ``.lproj`` folders
                if not '.lproj' in os.path.basename(root):
                    continue
            
            
            # Process files
            for f in files:
                
                # Get filenames and extensions
                filename, extension = os.path.splitext(os.path.basename(f))
                base_filename, base_extension = os.path.splitext(os.path.basename(base_path))
                
                # Get other
                absolute_f = root + '/' + f
                
                # Combine info
                filename_matches = filename == base_filename
                extension_matches = extension == base_extension
                is_base_file = absolute_f == base_path
                
                # Append
                if  not is_base_file and filename_matches:
                    if basetype == 'markdown':
                        translations[absolute_f] = {}
                    elif basetype == 'IB':
                        translations[absolute_f] = {}
                    elif basetype == 'strings':
                        if extension_matches:
                            translations[absolute_f] = {}
                    else:
                        assert False
        
        # Append
        e['translations'] = translations
    
    return result
        
        
    
    
    

#
# Call main
#
if __name__ == "__main__": 
    main()