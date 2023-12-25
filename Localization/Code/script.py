
#
# Imports
# 

import os
from pprint import pprint
import git

#
# Constants
#

#
# Main
#

def main():
    
    # Get info
    repo_root = os.getcwd()

    
    # Find localization files in MMF repo
    files = find_localization_files_in_mmf_repo(repo_root)
    
    # For each of the translation files, find the latest change and then find changes to the base file that occured later than that
    
    git_repo = git.Repo(repo_root)
    for file_dict in files:
        base_file = file_dict['base']
        
        for translation_file, translation_dict in file_dict['translations'].items():
            
            
            translation_commit_iterator = git_repo.iter_commits(paths=translation_file, **{'max-count': 1} ) # max-count is passed along to `git rev-list` command-line-arg
            last_translation_commit = next(translation_commit_iterator)
            
            outdating_commits = []
            
            base_commit_iterator = git_repo.iter_commits(paths=base_file)
            
            for base_commit in base_commit_iterator:
                if base_commit.committed_date > last_translation_commit.committed_date:
                    outdating_commits.append(base_commit)
                else:
                    break
            
                
            if len(outdating_commits) > 0:
                translation_dict['outdating_commits'] = outdating_commits
        
        
                
            
            
    
    
    pprint(files)
        

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