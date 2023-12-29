
#
# Native imports
#

import os
from pprint import pprint
import re
import subprocess
import tempfile
import argparse
import json
import textwrap

#
# Package imports
#

import git
import babel
import requests

#
# Constants
#

# Get info
repo_root = os.getcwd()

#
# Main
#

def main():
    
    parser = argparse.ArgumentParser()
    parser.add_argument('--api_key', required=True, help="See Apple Note 'MMF Localization Script Access Token'")
    args = parser.parse_args()

    files = find_localization_files_in_mmf_repo(repo_root)    
    analysis = analyze_localization_files(files, repo_root)
    markdown = markdown_from_analysis(analysis, repo_root)
    upload_markdown(args.api_key, markdown)
    
#
# Debug
#
def prepare_interactive_debugging(repo_root):
    
    """
    The analyze_localization_files() step in main() takes so longggg making it hard to debug any steps afterwards - Unless you're using python interactive mode!
    
    To debug from python interactive mode:
    
    1. Change working dir to the folder of this script. Then open python in interactive mode.
    2. >> import script, importlib
    3. >> from pprint import pprint (If necessary)
    4. >> result = script.prepare_interactive_debugging(<repo_root>) 
        - e.g. >> result = script.prepare_interactive_debugging("/Users/Noah/Desktop/mmf-stuff/mac-mouse-fix") 
    5. Play around with result 
        - e.g. >> print(script.markdown_from_analysis(result))
    6. >> importlib.reload(script) (after updating source code)
    """
        
    files = find_localization_files_in_mmf_repo(repo_root)    
    result = analyze_localization_files(files, repo_root)
    
    return result
    
#
# Upload Markdown
# 

def upload_markdown(api_key, markdown):
    
    """
    Upload the generated markdown to a comment on the "Localization Mac Mouse Fix" discussion (https://github.com/noah-nuebling/mac-mouse-fix/discussions/731)
    Notes:
    - Adding a comment will alert people who have notifications turned on for the discussion!
    - Find the api_key in the Apple Note `MMF Localization Script Access Token`
    - Use GitHub GraphQL Explorer to create queries (https://docs.github.com/en/graphql/overview/explorer)
    """
    
    # Log
    
    print(f"Uploading markdown ...")
    
    # Define Constants
    
    comment_prefix = "<!-- AUTOGEN_LOCALIZATION_ANALYSIS -->\n"
    new_comment_body = comment_prefix + markdown
    
    # Get comments on the discussion
    #   Note: If there are 100 comments since out comment last updated, then this might break. Seems unlikely though.
    
    comment_count = 100
    find_comment_query = textwrap.dedent(f"""
        {{
            repository(owner: "noah-nuebling", name: "mac-mouse-fix") {{
                discussion(number: 731) {{
                    id
                    comments(last:{comment_count}) {{
                        nodes {{
                            body
                            id
                        }}
                    }}
                }}
            }}                                    
        }}
    """)
    
    response = github_graphql_request(api_key, find_comment_query)
    
    # Log
    print(f"Downloaded comments for discussion. Not printing response as not to clutter up logs. But it might contain error messages.")
    
    # Parse
    discussion = response['data']['repository']['discussion']
    discussion_id = discussion['id']
    comments = discussion['comments']['nodes']
    
    # Find existing comment
    
    old_comment_id = ''
    old_comment_body = ''
    
    for comment in comments:
        
        body = comment['body']
        id = comment['id']
        
        if body.startswith(comment_prefix):
            old_comment_id = id
            old_comment_body = body
            break
        
    # Check if comment is outdated
    
    if new_comment_body == old_comment_body:
        print(f"Comment is already up-to-date. Not uploading anything.")
    else:
            
        # Delete existing comment
        # Note: We don't need the `clientMutationId`. Should probably remove from query

        if len(old_comment_id) == 0:
            print(f"Couldn't find existing comment. Nothing to delete.")
        else:
            
            delete_comment_query = textwrap.dedent(f"""
                mutation {{
                    deleteDiscussionComment(input:{{id: "{old_comment_id}"}}) {{
                        clientMutationId
                    }}
                }}
            """)
            
            response = github_graphql_request(api_key, delete_comment_query)
            
            # Log
            print(f"Deleted comment with id {old_comment_id}. Response: {response}")
            
        
        # Add new comment
        
        new_comment_body_escaped = new_comment_body.replace('"', r'\"')
        
        add_comment_query = textwrap.dedent(f"""
            mutation {{
                addDiscussionComment(input: {{discussionId: "{discussion_id}", body: "{new_comment_body_escaped}"}}) {{
                    comment {{
                        publishedAt
                        id
                        databaseId
                    }}
                }}
            }}
        """)
        
        response = github_graphql_request(api_key, add_comment_query)
        
        # Log
        print(f"Uploaded comment! Response: {response}")
    
# 
# Helper for Upload Markdown
#

def github_graphql_request(api_key, query):

    # Define header
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    # Make request
    response = requests.post('https://api.github.com/graphql', json={'query': query}, headers=headers)

    # Parse the response
    result = response.json()
    
    # Return 
    return result

#
# Build markdown
#

def markdown_from_analysis(files, repo_root):
    
    # Discussion:
    # We want to always produce the exact same markdown for a given input. That's because we plan to send notifications to collaborators whenever the markdown changes.
    # This is why we're sorting all of the things we iterate through. I'm not sure this is necessary, since Python 3.7 and higher iterate through dict `.items()` in insertion order anyways.
    # But I still think the sorting should make it more robust, especially also against changes in the code that produces the analysis.
    
    # Log
    print("Generating markdown from analysis...")
    
    # Build content and split it up by language
    
    result_by_language = dict()
    
    for file_dict in sorted(files, key=lambda f: f['base']):
        
        base_file_path = file_dict['base']
        base_file_display_short, base_file_display, base_file_link = file_paths_for_markdown(base_file_path, repo_root)
        
        for translation_file_path in sorted(file_dict['translations'].keys()):
            translation_dict = file_dict['translations'][translation_file_path]
            
            translation_file_display_short, translation_file_display, translation_file_link = file_paths_for_markdown(translation_file_path, repo_root)
            
            _, file_type = os.path.splitext(translation_file_path)
            
            content_str = ''
            
            if file_type == '.md' or file_type == '.stringsdict':
                
                # Build user strings using outdating_commits
                #   Since we don't analyze keys for these files
                
                outdating_commits = list(map(lambda c: f'{c.hexsha}', translation_dict.get('outdating_commits', [])))
                outdating_commit_strs = []
                for c in outdating_commits:
                    c_short, link = commit_strings_for_markdown(c, repo_root)
                    outdating_commit_strs.append(f"[{c_short}]({link})")
                    
                if len(outdating_commit_strs) > 0:
                    outdating_commit_str = ",\n".join(outdating_commit_strs)
                    content_str += f'\n\n**Changes to base file after the latest change to the translation**\n\n{outdating_commit_str}'
                    
            elif file_type == '.js' or file_type == '.strings':
                
                # Build strings for missing/superfluous translations
                
                missing_str = ',\n'.join(map(lambda x: f'`"{x["key"]}"`: `"{x["value"]}"`', translation_dict['missing_translations'])) # Not sure why we need to escape the `|` here.
                if len(missing_str) > 0:
                    content_str += f"\n\n**Missing translations**\n\n{missing_str}"
                    
                superfluous_str = ',\n'.join(map(lambda x: f'`"{x["key"]}"`: `"{x["value"]}"`', translation_dict['superfluous_translations']))
                if len(superfluous_str) > 0:
                    content_str += f"\n\n**Superfluous translations**\n\n{superfluous_str}"
                
                # Build strings for outdated translations
                
                outdated_str = ''
                for translation_key in sorted(translation_dict.get('outdated_translations', {}).keys()):
                    
                    changes = translation_dict['outdated_translations'][translation_key]
                    
                    base_change = changes['latest_base_change']
                    translation_change = changes['latest_translation_change']
                    base_before         = escape_for_markdown(base_change["before"] or "")
                    base_after          = escape_for_markdown(base_change["after"] or "")
                    translation_before  = escape_for_markdown(translation_change["before"] or "")
                    translation_after   = escape_for_markdown(translation_change["after"] or "")
                    
                    base_commit = base_change["commit"].hexsha
                    translation_commit = translation_change["commit"].hexsha
                    base_commit_short, base_commit_link = commit_strings_for_markdown(base_commit, repo_root)
                    translation_commit_short, translation_commit_link = commit_strings_for_markdown(translation_commit, repo_root)
                    
                    outdated_str = textwrap.dedent(f"""
                                                    
                        `"{translation_key}"`: `"{translation_after}"`
                        - Latest change in base file:
                          `"{base_before}"` -> `"{base_after}"`
                          in commit [{base_commit_short}]({base_commit_link})
                        - Latest change in translation: 
                          `"{translation_before}"` -> `"{translation_after}"`
                          in commit [{translation_commit_short}]({translation_commit_link})
                    """)
                    
                if len(outdated_str) > 0:
                    content_str += f"\n\n**Outdated translations**{outdated_str}"
                    
            else:
                assert False, f"Trying to build markdown for invalid file_type {file_type}"
        
            # Attach string to result
            # Note: Textwrap dedent just won't work here. No idea why.
            if len(content_str) > 0:
                language_id = translation_dict['language_id']
                content_str = textwrap.dedent(f"""
## {translation_file_display_short}
Translation at: [{translation_file_display}]({translation_file_link})
Base file at: [{base_file_display}]({base_file_link}){content_str}
                """)
                result_by_language.setdefault(language_id, []).append(content_str)

    # Build result from result_by_language
    
    result = ''
    
    for language_id in sorted(result_by_language.keys()):
        
        content_strs = result_by_language[language_id]
        
        # Get language name
        locale = babel.Locale.parse(language_id, sep='-')
        language_name = locale.english_name

        # Attach to result
        result += f"\n\n# {language_name}"
        for content_str in content_strs:
            result += content_str
    
    if len(result) > 0:
        result = textwrap.dedent(f"""\
            In this comment you can find a list of translations that might need updating:
        """) + result
    
    return result

#
# Helper for build markdown
#

def escape_for_markdown(s):
    return s.replace(r'\n', r'\\n').replace(r'\t', r'\\t').replace(r'\r', r'\\r')

def commit_strings_for_markdown(commit_hash, local_repo_path):
    
    repo_name = os.path.basename(local_repo_path)
    assert repo_name == 'mac-mouse-fix' or repo_name == 'mac-mouse-fix-website', "Can't get paths for unknown repo {repo_name}"
    
    link = f'https://github.com/noah-nuebling/{repo_name}/commit/{commit_hash}'
    display_short = commit_hash[:7] # The short hashes displayed on GH and elsewhere have the first 7 chars IIRC
    
    return display_short, link

def file_paths_for_markdown(local_path, local_repo_path):
    
    repo_name = os.path.basename(local_repo_path)
    assert repo_name == 'mac-mouse-fix' or repo_name == 'mac-mouse-fix-website', "Can't get paths for unknown repo {repo_name}"
    
    relpath = os.path.relpath(local_path, local_repo_path)
    
    gh_root = ''
    if repo_name == 'mac-mouse-fix':
        gh_root = 'https://github.com/noah-nuebling/mac-mouse-fix/blob/master'
    else:
        gh_root = 'https://github.com/noah-nuebling/mac-mouse-fix-website/blob/master'

    display_short = os.path.basename(local_path)
    display = repo_name + '/' + relpath
    link = gh_root + '/' + relpath
    
    return display_short, display, link
#
# Analysis core
#

def analyze_localization_files(files, repo_root):

    """
        Structure of the analysis result: (at time of writing) (This takes the input file and just fills in stuff)
        [
            {
                'base': '<base_file_path>',
                'translations': {
                    <translation_file_path>: {
                        'outdating_commits': [<commits_to_base_files_after_the_latest_commit_to_translation_file>],
                        'missing_translations': [{ 'key': <translation_key>, 'value': <ui_text> }, ...],
                        'superfluous_translations': [{ 'key': <translation_key>, 'value': <ui_text> }, ...],
                        'outdated_translations': {
                            '<translation_key>': {
                                'latest_base_change': {
                                    'commit': git.Commit(<commit_of_lastest_base_change>),
                                    'before': '<ui_text>',
                                    'after': '<ui_text>',
                                },
                                'latest_translation_change': {
                                    'commit': git.Commit(<commit_of_latest_translation_change>),
                                    'before': '<ui_text>',
                                    'after': '<ui_text>',
                                }
                            },
                            '<translation_key>': {
                                ...
                            },
                            ...
                        },
                    },
                    <translation_file_path>: {
                        ...
                    },
                    ...
                }
            },
            {
                'base': '<base_file_path>',
                ...
            },
            ...
        ]
    """
    
    files = files.copy()
    
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
    print(f'  Analyzing changes to translation keys and values...')
    
    # Analyze changes to translation keys
    for file_dict in files:
        
        # Get base file info
        base_file_path = file_dict['base']
        _, file_type = os.path.splitext(base_file_path)
        
        # Skip
        if not (file_type == '.js' or file_type == '.strings' or file_type == '.xib' or file_type == '.storyboard'):
            continue
        
        # Log
        print(f'    Processing base translation at {base_file_path}...')
        
        # Find basefile keys
        base_keys_and_values = extract_translation_keys_and_values_from_file(file_dict['base'])
        if base_keys_and_values == None: continue
        base_keys = set(base_keys_and_values.keys())
        
        # For each key in the base file, get the commit, when it last changed  
        latest_base_changes = get_latest_change_for_translation_keys(base_keys, base_file_path, git_repo)
        
        for translation_file_path, translation_dict in file_dict['translations'].items():
            
            # Log
            print(f'      Processing translation of {os.path.basename(base_file_path)} at {translation_file_path}...')
            print(f'        Find translation keys and values...')
            
            # Find translation file keys
            translation_keys_and_values = extract_translation_keys_and_values_from_file(translation_file_path)
            translation_keys = set(translation_keys_and_values.keys())
            
            print(f'        Check missing/superfluous keys...')
            
            # Do set operations
            missing_keys = base_keys.difference(translation_keys)
            superfluous_keys = translation_keys.difference(base_keys)
            common_keys = base_keys.intersection(translation_keys)
            
            # Get and attach missing / superfluous translations
            missing_translations        = list(map(lambda k: {'key': k, 'value': base_keys_and_values[k]['value']}, missing_keys))
            superfluous_translations    = list(map(lambda k: {'key': k, 'value': translation_keys_and_values[k]['value']}, superfluous_keys))
            translation_dict['missing_translations'] = missing_translations
            translation_dict['superfluous_translations'] = superfluous_translations
            
            # Log
            print(f'        Analyze when keys last changed...')
            
            # Check common keys if they are outdated.
            
            # For each key, get the commit when it last changed
            latest_translation_changes = get_latest_change_for_translation_keys(common_keys, translation_file_path, git_repo)
            
            # Log
            print(f'        Check if last modification was before base for each key ...')
            
            # Compare time of latest change for each key between base file and translation file
            for k in common_keys:
                
                # if k == 'capture-toast.body':
                #     pprint(f"translation_dict: {translation_dict}")
                #     break
                
                base_commit = latest_base_changes[k]['commit']
                translation_commit  = latest_translation_changes[k]['commit']
                
                base_commit_is_predecessor = is_predecessor(base_commit, translation_commit)
                
                # DEBUG
                #     print(f"latest_base_change: {base_file_path}, change: {base_commit}")
                #     print(f"translated_change: {translation_file_path}, change: {translation_commit}")
                #     print(f"base_is_predecessor: {base_commit_is_predecessor}")
                
                if not base_commit_is_predecessor:
                    translation_dict.setdefault('outdated_translations', {})[k] = { 'latest_base_change': latest_base_changes[k], 'latest_translation_change': latest_translation_changes[k] }    
    
    # Return
    return files

#
# Change analysis
#

def get_latest_change_for_translation_keys(wanted_keys, file_path, git_repo):
    
    """
    Structure of result:
    {
        "<translation_key>": {
            "commit": "<commit_on_which_value_last_changed>",
            "before": "<translation_value_before_commit>",
            "after": "<translation_value_after_commit>",
        }, 
        "<translation_key>": {
            ...
        },
        ...
    }
    """
    
    # Declare stuff
    repo_root = git_repo.working_tree_dir
    result = dict()
    wanted_keys = wanted_keys.copy()
    _, file_type = os.path.splitext(file_path)
    
    # Preprocess file_type
    t = 'strings' if (file_type == '.strings' or file_type == '.js') else 'IB' if (file_type == '.xib' or file_type == '.storyboard') else None
    if t == None:
        assert False, f"Trying to get latest key changes for incompatible filetype {file_type}"
    
    # Define reusable helper 
    def parse_diff_and_update_state(diff_string, commit, result, wanted_keys):
        
        keys_and_values = extract_translation_keys_and_values_from_string(diff_string)
    
        for key, changes in keys_and_values.items():
            
            if (key not in result) and (key in wanted_keys):
                added_value = changes.get('added', None)
                deleted_value = changes.get('deleted', None)
                if added_value != deleted_value:
                    new_entry = { 'commit': commit, 'before': deleted_value, 'after': added_value }
                    result[key] = new_entry
                    wanted_keys.remove(key)    
                    # print(f"parsing diff - adding new entry: {new_entry}")
    
    if t == 'strings':
        
        for i, commit in enumerate(git_repo.iter_commits(paths=file_path, reverse=False)):
            
            # Break
            if len(wanted_keys) == 0:
                break
            
            # Get diff string
            #   Run git command 
            #   - For getting additions and deletions of the commit compared to its parent
            #   - I tried to do this with gitpython but nothing worked, maybe I should stop using it altogether?
            diff_string = runCLT(f"git diff -U0 {commit.hexsha}^..{commit.hexsha} -- {file_path}").stdout
            
            # Parse diff
            parse_diff_and_update_state(diff_string, commit, result, wanted_keys)
                
    elif t == 'IB':
        
        # Notes:
        # - This seems to be by far the slowest part of the script. It's still fast enough, but maybe look into optimizing.
        # -     Possible sources of slowness: subprocess calls (I read that command is faster), file-creations/reads/writes, complex git commands.
        
        commits = list(git_repo.iter_commits(paths=file_path, reverse=False))
        commits.append(None)
        
        last_strings_file_path = ''
        
        for i, commit in enumerate(commits):
            
            # Break
            if len(wanted_keys) == 0:
                break
            
            # Get strings file for this commit
            if commit == None:
                # This case is weird
                #   The 'None' commit symbolizes the parent of the initial commit of the file.
                #   We say the parent of the strings file at the initial commit is an empty file, that way we can get diff values in the format we expect for the initial commit.
                assert i == (len(commits) - 1)
                strings_file_path = create_temp_file()
            else:
                file_path_relative = os.path.relpath(file_path, repo_root) # `git show` breaks with absolute paths
                file_path_at_this_commit = create_temp_file(suffix=file_type)
                runCLT(f"git show {commit.hexsha}:{file_path_relative} > {file_path_at_this_commit}")
                strings_file_path = extract_strings_from_IB_file_to_temp_file(file_path_at_this_commit)
                
            if i != 0: 
                
                # Notes: 
                #  We skip the first iteration. That's because, on the first iteration,
                #  there's no `last_strings_file_path` to diff against.
                #  To 'make up' for this lack of diff on the first iteration, we have the extra 'None' commit. 
                #  Kind of confusing but it should work.
                
                # Validate
                assert last_strings_file_path != ''
                
                # Get diff string
                diff_string = runCLT(f"git diff -U0 --no-index -- {strings_file_path} {last_strings_file_path}").stdout
                
                # Parse diff
                parse_diff_and_update_state(diff_string, commits[i-1], result, wanted_keys)
                
                # Cleanup
                os.remove(last_strings_file_path)
            
            # Update state
            last_strings_file_path = strings_file_path
            
    else:
        assert False

    # Return
    return result

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
            "added"<?>: "<translation_value>",
            "deleted"<?>: "<translation_value>",
            "value"<?>: "<translation_value>",
        }
        "<translation_key>": {
            ...
        },
        ... 
    }

    ... where <?> means that the key is optional. 
        If the input text is a git diff text with - and + at the start of lines, then the result with contain `added` and `deleted` keys, otherwise, the result will contain `value` keys.
    """
        
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
    
    temp_file_path = create_temp_file()
        
    cltResult = subprocess.run(f"/usr/bin/ibtool --export-strings-file {temp_file_path} {ib_file_path}", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        
    if len(cltResult.stdout) > 0 or len(cltResult.stderr) > 0:
        # Log & Crash
        print(f"Error: ibtool failed. Printing feedback ... \nstdout: {cltResult.stdout}\nstderr: {cltResult.stderr}")
        exit(1)
    
    # Convert to utf-8
    #   For some reason, ibtool outputs strings files as utf-16, even though strings files in Xcode are utf-8 and also git doesn't understand utf-8.
    convert_utf16_file_to_utf8(temp_file_path)
    
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

def is_predecessor(potential_predecessor_commit, commit):
    
    # Check which commit is 'earlier'. Works kind of like potential_predecessor_commit <= commit (returns true for equality)
    # Not totally sure what we're doing here. 
    #   - First, we were checking for ancestry with `git merge-base``, but that slowed the whole script down a lot (maybe we could've alleviated that by changing runCLT? We have some weird options there.) (We also tried `rev-list --is-ancestor`, but it didn't help.)
    #   - Then we updated to just comparing the commit date. I think it might make less sense than checking ancestry, and might lead to wrong results, maybe? But currently it seems to work okay and is faster. 
    #   - Not sure if `committed_date` or `authored_date` is better. Both seem to give the same results atm.
        
    return potential_predecessor_commit.committed_date <= commit.committed_date
    # return runCLT(f"git rev-list --is-ancestor {potential_predecessor_commit.hexsha} {commit.hexsha}").returncode == 0
    # return runCLT(f"git merge-base --is-ancestor {potential_predecessor_commit.hexsha} {commit.hexsha}").returncode == 0

def runCLT(command):
    clt_result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) # Not sure what `text` and `shell` does.
    return clt_result

#
# Find files
#

def find_localization_files_in_mmf_repo(repo_root):
    
    """
    Find localization files
    
    Structure of the result:
    [
        {  
            "base": "<path_to_base_localization_file>", 
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
    """
    
    # Log
    print(f'Finding translation files inside MMF repo...')
    
    # Validate
    assert repo_root[-1] != '/', "repo_root strings ends with /. Remove it."
    
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
                if is_en_folder: assert extension in ['.strings', '.stringsdict'], f"en.lproj folder at {b} contained file with extension {extension}"
                if is_base_folder: assert extension in ['.xib', '.storyboard'], f"Base.lproj folder at {b} contained file with extension {extension}"
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
        del e['basetype']
        
        translations = {}
        
        # Get grandparent dir of the base file, which contains all the translation files
        grandpa = os.path.dirname(os.path.dirname(base_path))
        
        for root, dirs, files in os.walk(grandpa):
            
            if basetype == 'IB' or basetype == 'strings':
                
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
                
                # Get language id
                language_id = ''
                if basetype == 'nuxt':
                    language_id = filename
                else:
                    language_id, _ = os.path.splitext(os.path.basename(root))
                
                # Get other
                absolute_f = root + '/' + f
                
                # Combine info
                filename_matches = filename == base_filename
                extension_matches = extension == base_extension
                is_base_file = absolute_f == base_path
                
                # Append
                if  not is_base_file and filename_matches:
                    if basetype == 'markdown':
                        translations[absolute_f] = { "language_id": language_id }
                    elif basetype == 'IB':
                        translations[absolute_f] = { "language_id": language_id }
                    elif basetype == 'strings':
                        if extension_matches:
                            translations[absolute_f] = { "language_id": language_id }
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