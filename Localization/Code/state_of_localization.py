"""
This script creates the "🌏 State of Localization 🌎" comment on discussion #731 (https://github.com/noah-nuebling/mac-mouse-fix/discussions/731)

Checklist:

- [x] Why isn’t website stuff showing up? -> Forgot to turn debug stuff off
- [x] Why unchanged translations not showing ‘Mac Mouse Fix’? -> they were actually changed, with non-breaking spaces

- [x] Add ‘empty_translations’ section
- [x] Add ‘untranslated files’ section

- [x] Write tutorial for updating existing translations.
- [x] Test if this correctly tracks changes through renames of different file types (.js and .strings files, IB files, .stringsdict and .md files)

- [x] Write a GitHub Action that runs on every push to master / every 24 hours.
"""


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
from datetime import datetime
import difflib

#
# Package imports
#

import git
import babel
import requests

#
# Constants
#

language_flag_fallback_map = { # When a translation's languageID doesn't contain a country, fallback to these flags
    'zh': '🇨🇳',       # Chinese maps to China
    'ko': '🇰🇷',       # Korean maps to South Korea
    'de': '🇩🇪',       # German maps to Germany
    'vi': '🇻🇳',       # Vietnamese maps to Vietnam
}

#
# Main
#

def main():
    
    parser = argparse.ArgumentParser()
    parser.add_argument('--api_key', required=True, help="See Apple Note 'MMF Localization Script Access Token'")
    args = parser.parse_args()


    repo_root = os.getcwd()
    website_root = repo_root + '/' + "../mac-mouse-fix-website"
    assert os.path.basename(repo_root) == 'mac-mouse-fix', "Run this script from the 'mac-mouse-fix' repo folder."
    assert os.path.exists(website_root), "Couldn't find mmf website repo at {website_root}"
    
    files = find_localization_files(repo_root, website_root)
    missing_analysis = analyze_missing_localization_files(files)
    analysis = analyze_localization_files(files)
    markdown = markdown_from_analysis(analysis, missing_analysis)
    upload_markdown(args.api_key, markdown)
    
#
# Debug
#
def prepare_interactive_debugging(repo_root, website_root):
    
    """
    The analyze_localization_files() step in main() takes so longggg making it hard to debug any steps afterwards - Unless you're using python interactive mode!
    
    To debug from python interactive mode:
    
    1. Change working dir to the folder of this script. Then open python in interactive mode.
    2. >> import state_of_localization as script, importlib
    3. >> from pprint import pprint (If necessary)
    4. >> result = script.prepare_interactive_debugging(<repo_root>, <website_root>) 
        - e.g. >> result = script.prepare_interactive_debugging("/Users/Noah/Desktop/mmf-stuff/mac-mouse-fix", "/Users/Noah/Desktop/mmf-stuff/mac-mouse-fix-website")
    5. Play around with result 
        - e.g. >> print(script.analyze_missing_localization_files(result))
        - e.g. >> print(script.markdown_from_analysis(result, script.analyze_missing_localization_files(result)))
        - e.g. >> script.upload_markdown('<api_key>', script.markdown_from_analysis(result, script.analyze_missing_localization_files(result)))
            (See Apple Note "MMF Localization Script Access Token")
    6. >> importlib.reload(script) (after updating source code)
    """
        
    files = find_localization_files(repo_root, website_root)
    result = analyze_localization_files(files)
    
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
        
        print(f"The comment has changed. Diff:\n{get_diff_string(old_comment_body, new_comment_body)}")
            
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
        
        new_comment_body_escaped = escape_for_upload(new_comment_body) # Should we escape before the outdated check above?
        
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
        
        # Debug
        # print(f"Add comment query: {repr(add_comment_query)}")
        
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

def markdown_from_analysis(files, missing_files):
    
    """
    Discussion:
    We want to always produce the exact same markdown for a given input. That's because we plan to send notifications to collaborators whenever the markdown changes.
    This is why we're **sorting** all of the things we iterate through. Since Python 3.7 and higher iterating through dict `.items()` is alledgedly in insertion order. 
        But sorting everything still seems to be necessary to get consistent outputs. (Under python 3.11)
    
    It's easy to forget to sort.
    
    One way I found to **test if this function sorts properly**:
        Go to get_commits_follow_renames() and swap between the old `iter_commits` approach and the new `git log --follow` approach. 
        Before we sorted this properly, that switch totally changed the order (but not the content) of the resulting markdown.
    
    To find unsorted iterations:
        Find for loops and list comprehensions by searching for 'for'. Also search for `map`. 
        Other ways to iterate dicts are `dict comprehensions` and `generator expressions`. But I don't think we'll ever use those.
    """
    
    # Log
    print("Generating markdown from analysis...")
    
    # Build content and split it up by language
    
    result_by_language = dict()
    
    for file_dict in sorted(files, key=lambda f: f['base']):
        
        repo = file_dict['repo']
        repo_root = repo.working_tree_dir
        
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
                
                outdating_commits = translation_dict.get('outdating_commits', {})
                latest_translation_commit = outdating_commits.get('latest_translation_change', None)
                newer_base_changes = outdating_commits.get('newer_base_changes', [])
                    
                if len(newer_base_changes) > 0:
                    
                    latest_translation_commit_str = commit_string_for_markdown(latest_translation_commit, repo_root)
                    latest_translation_commit_date_str = commit_date_for_markdown(latest_translation_commit)
                    
                    newer_base_changes_strs = []
                    for c in sorted(newer_base_changes):
                        commit_str = commit_string_for_markdown(c, repo_root)
                        commit_date_str = commit_date_for_markdown(c)
                        newer_base_changes_strs.append(f"On `{commit_date_str}` in commit {commit_str}")
                    newer_base_changes_str = "\n- ".join(newer_base_changes_strs)
                    
                    content_str += textwrap.dedent(f"""\
                        
The latest change to the translation was on `{latest_translation_commit_date_str}` in commit {latest_translation_commit_str}.

The base file changed after that: 
- {newer_base_changes_str}

Maybe the translation should be updated to reflect the new changes to the base file.\
""") # dedent stopped working all of a sudden. No idea why.
                    
            elif file_type == '.js' or file_type == '.strings':
                
                # Build strings for missing/superfluous translations
                
                missing_str =       '\n- '.join(map(lambda x: translation_to_markdown(x['key'], x['value'], file_type), sorted(translation_dict['missing_translations'], key=lambda x: x['key']))) # Not sure why we need to escape the `|` here.
                if len(missing_str) > 0:
                    content_str += f"\n\n**Missing translations**\n\nThe following key-value-pairs appear in the base file but not in the translation. They should probably be added to the translation:\n\n- {missing_str}"
                    
                superfluous_str =   '\n- '.join(map(lambda x: translation_to_markdown(x['key'], x['value'], file_type), sorted(translation_dict['superfluous_translations'], key=lambda x: x['key'])))
                if len(superfluous_str) > 0:
                    content_str += f"\n\n**Superfluous translations**\n\nThe following key-value-pairs appear in the translation but not in the base file. It's likely they are unused and can be deleted from the translation:\n\n- {superfluous_str}"
                    
                unchanged_str =     '\n- '.join(map(lambda x: translation_to_markdown(x['key'], x['value'], file_type), sorted(translation_dict['unchanged_translations'], key=lambda x: x['key'])))
                if len(unchanged_str) > 0:
                    content_str += f"\n\n**Unchanged translations**\n\nThe following key-value-pairs have the exact same value in the translation as in the base file. Maybe they have not yet been translated:\n\n- {unchanged_str}"
                
                empty_str =         '\n- '.join(map(lambda x: f"Base file: {translation_to_markdown(x['key'], x['base_value'], file_type)}\n  Translation: {translation_to_markdown(x['key'], x['value'], file_type)}", sorted(translation_dict['empty_translations'], key=lambda x: x['key'])))
                if len(empty_str) > 0:
                    content_str += f"\n\n**Empty translations**\n\nThe following key-value-pairs are empty in the translation but not empty in the base file. It looks like they have not yet been translated:\n\n- {empty_str}"
                    
                
                # Build strings for outdated translations
                
                outdated_str = ''
                for translation_key in sorted(translation_dict.get('outdated_translations', {}).keys()):
                    
                    changes = translation_dict['outdated_translations'][translation_key]
                    
                    base_change = changes['latest_base_change']
                    translation_change = changes['latest_translation_change']
                    
                    ddd = { 'text': "" }
                    base_before         = escape_for_markdown((base_change["before"] or ddd)['text'])
                    base_after          = escape_for_markdown((base_change["after"] or ddd)['text'])
                    translation_before  = escape_for_markdown((translation_change["before"] or ddd)['text'])
                    translation_after   = escape_for_markdown((translation_change["after"] or ddd)['text'])
                    
                    base_commit = base_change["commit"]
                    translation_commit = translation_change["commit"]
                    base_commit_str = commit_string_for_markdown(base_commit, repo_root)
                    base_commit_date_str = commit_date_for_markdown(base_commit)
                    translation_commit_str = commit_string_for_markdown(translation_commit, repo_root)
                    translation_commit_date_str = commit_date_for_markdown(translation_commit)
                    
                    def value_change_to_markdown(before, after, file_type):
                        a = translation_value_to_markdown(before, file_type, escape=False)
                        b = translation_value_to_markdown(after, file_type, escape=False)
                        break_line = len(a) + len(b) > 80
                        line_breaker = '\n    ' if break_line else ' '
                        
                        return f"{a} ->{line_breaker}{b}"
                    
                    outdated_str += textwrap.dedent(f"""\
                                                    
                                                    
{translation_to_markdown(translation_key, translation_after, file_type, escape_value=False)}
- Latest change in translation: 
    {value_change_to_markdown(translation_before, translation_after, file_type)}
    on {translation_commit_date_str} in commit {translation_commit_str}
- Latest change in base file:
    {value_change_to_markdown(base_before, base_after, file_type)}
    on {base_commit_date_str} in commit {base_commit_str}
""")
                    
                if len(outdated_str) > 0:
                    content_str += f"\n\n**Outdated translations**\n\nThe following key-value-pairs have been changed in the base file without a subsequent change in the translation. Maybe they should be updated in the translation to reflect the change in the base file:{outdated_str}"
                    
            else:
                assert False, f"Trying to build markdown for invalid file_type {file_type}"
        
            # Attach string to result
            # Note: Textwrap dedent just won't work here. No idea why.
            if len(content_str) > 0:
                language_id = translation_dict['language_id']
                content_str = (f"""\
                    
## File: {translation_file_display_short}

Translation at: [{translation_file_display}]({translation_file_link})
Base file at: [{base_file_display}]({base_file_link})

To help update the translations inside [{translation_file_display}]({translation_file_link})
see **Updating Translation Files** at the top of the page.

{content_str}\
""")
                result_by_language.setdefault(language_id, []).append(content_str)


    # Attach missing files info to result_by_language
    for language_id in sorted(result_by_language.keys()):
        
        content_strs = result_by_language[language_id]
        
        missing_str = ''
        
        translated = missing_files[language_id].get('translated_files', [])
        untranslated = missing_files[language_id].get('untranslated_files', [])
        
        for b in sorted(untranslated, key=lambda b: b['base']):
            
            b_short, b_display, b_link = file_paths_for_markdown(b['base'], b['repo'].working_tree_dir)
            
            # Note: Here, we make the assumption that translation files for App, Website, and GitHub each have non-overlapping file extensions. 
            #       This might very well break in the future! For example when we render Website pages from .md.
            
            _, extension = os.path.splitext(b_short)
            section_name = ("Adding a Language to the App" if extension in ['.strings', '.stringsdict', '.xib', '.storyboard'] else 
                            "Adding a Language to the Website" if extension in ['.js'] else 
                            "Adding a Language to the GitHub" if extension in ['.md'] else 
                            None)
            assert section_name != None, f"Couldn't determine tutorial section name for file with unknown extension {extension}"
            
            missing_str += f"- [{b_short}]({b_link})\n  See **{section_name}** at the top of the page to learn how to translate this file.\n"
        
        for d in sorted(translated, key=lambda d: d['base']):
            
            continue
        
            b = d['base']
            t = d['translation']
            b_short, b_display, b_link = file_paths_for_markdown(b, repo_root)
            t_short, t_display, t_link = file_paths_for_markdown(t, repo_root)
            
            missing_str += f"- Translation for [{b_short}]({b_link})\n  is at [{t_short}]({t_link})\n"
            
        # Attach
        if len(missing_str) > 0:
            content_strs = content_strs.insert(0, '\n\n## Missing Files\n\nThe following files don\'t have a translation for this language, yet:\n\n' + missing_str)
            
    
    # Build rrresult from result_by_language
    
    rrresult = ''
    
    for language_id in sorted(result_by_language.keys()):
        
        content_strs = result_by_language[language_id]
        
        # Get language name
        locale = babel.Locale.parse(language_id, sep='-')
        language_name = locale.english_name
        flag_emoji = language_tag_to_flag_emoji(language_id)

        # Attach language header
        rrresult += f"\n\n# {flag_emoji} {language_name} | {language_id}"    
        
        # Attach file analysis
        for content_str in sorted(content_strs):
            rrresult += content_str
    
    if len(rrresult) == 0:
        rrresult = "All translations seem to be up-to-date at the moment! This comment will be updated if there are any translations that need updating."
    
    # Attach intro and outro
    # Discussion:
    #   I wanted to add a text here saying 'this was generated on <date>', but that would make it so the comment updates at least once a day, which would lead to people getting daily notifications I think.
    result = textwrap.dedent(f"""\
# 🌏 State of Localization 🌎

This comment lists potential problems with the different translations of Mac Mouse Fix.

You can use the information here to help improve translations of Mac Mouse Fix.\

If you have any questions, add a comment below.
If you find any problem with a translation that doesn't show up here, add a comment below. 

{rrresult}

---

Don't reply to this comment, as this comment will be deleted (and recreated) periodically, which will also delete your reply. Instead, add a new comment.
""")
    
    return result

#
# Helper for build markdown
#

def translation_value_to_markdown(value, file_type, escape=True):
    
    
    if escape:
        value = escape_for_markdown(value)
    
    cutoff = 250
    
    quoted = ''
    if len(value) == 0:
        quoted = ''
    elif len(value) <= cutoff:
        quoted = f"`{value}`"
    else:
        quoted = "`[This text is very long. You can see it in the linked commit/translation file.]`"
    
    result = ''
    if file_type == '.strings':
        result = f'"{quoted}"'
    elif file_type == '.js':
        result = f"'{quoted}'"
    
    return result

def translation_to_markdown(key, value, file_type, escape_value=True):
    
    value_str = translation_value_to_markdown(value, file_type, escape_value)
    
    result = ''
    if file_type == '.strings':
        result = f'"`{key}`" = {value_str};'
    elif file_type == '.js':
        result = f"'`{key}`': {value_str},"
    else:
        assert False
    
    return result

def language_tag_to_flag_emoji(language_id):
    
    # Define helper
    def get_flag(country_code):
        return ''.join(chr(ord(c) + 127397) for c in country_code.upper())
    
    # Parse language tag
    locale = babel.Locale.parse(language_id, sep='-')
    
    # Get flag from country code
    if locale.territory:
        return get_flag(locale.territory)
    
    flag = language_flag_fallback_map.get(locale.language, None)
    if flag:
        return flag
    
    # Fallback to Unicode 'Replacement Character' (Missing emoji symbol/questionmark-in-rectangle symbol)
    return "&#xFFFD;" 

def escape_for_markdown(s):
    
    # This is to make `s` display verbatim in markdown.
    # Update: This is not necessary anymore after we started using `escape_for_upload()`
    
    return s #.replace(r'\n', r'\\n').replace(r'\t', r'\\t').replace(r'\r', r'\\r')

def escape_for_upload(s):
    # This is to be able to upload a string through the GitHub GraphQL API.
    # Src: https://www.linkedin.com/pulse/graphql-parse-errors-parul-aditya-1c
    
    # return s.replace('"', r'\"')#.replace(r'+', r'\+').replace(r'\\', r'\\\\')
    
    return (s.replace("\\", "\\\\")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t")
            .replace("\f", "\\f")
            .replace('"', '\\"'))

def commit_string_for_markdown(commit, local_repo_path):
    
    commit_hash = commit.hexsha
    
    repo_name = os.path.basename(local_repo_path)
    assert repo_name == 'mac-mouse-fix' or repo_name == 'mac-mouse-fix-website', "Can't get paths for unknown repo {repo_name}"
    
    link = f'https://github.com/noah-nuebling/{repo_name}/commit/{commit_hash}'
    display_short = commit_hash[:7] # The short hashes displayed on GH and elsewhere have the first 7 chars IIRC
    
    return f"[{display_short}]({link})"

def commit_date_for_markdown(commit):
    commit_date_unix = commit.committed_date # Unix timestamp
    date_str = unix_date_for_markdown(commit_date_unix)
    return date_str

def unix_date_for_markdown(unix_timestamp):
    date_str = datetime.fromtimestamp(unix_timestamp).strftime('%d.%m.%Y')
    return date_str

def file_paths_for_markdown(local_path, local_repo_path):
    
    repo_name = os.path.basename(local_repo_path)
    assert repo_name == 'mac-mouse-fix' or repo_name == 'mac-mouse-fix-website', "Can't get paths for unknown repo {repo_name}"
    
    relpath = os.path.relpath(local_path, local_repo_path)
    
    gh_root = ''
    if repo_name == 'mac-mouse-fix':
        gh_root = 'https://github.com/noah-nuebling/mac-mouse-fix/blob/master'
    else:
        gh_root = 'https://github.com/noah-nuebling/mac-mouse-fix-website/blob/main'

    display_short = os.path.basename(local_path) # + (" (Website)" if repo_name == 'mac-mouse-fix-website' else '')
    display = repo_name + '/' + relpath
    link = gh_root + '/' + relpath
    
    return display_short, display, link
#
# Analysis core
#

def analyze_missing_localization_files(files):

    """
    Structure of output:
    {
        '<language_id>: {
           'translated_files': [
                {
                    'base': '<base_file_path>',
                    'translation': '<translated_file_path>',
                    'repo': git.Repo(),
                },
                ...
            ],
            'untranslated_files': [
                {
                    'base': '<base_file_path>',
                    'repo': git.Repo(),
                },
                ...
            ]
        },
        ...
    }
    """

    # Log
    print("Analyzing which localization files are missing...")
    
    # Get base files & translated files
    
    base_files = list()
    result = dict()
    for file_dict in files:
        base_path = file_dict['base']
        repo = file_dict['repo']
        base_files.append({ 'base': base_path, 'repo': repo })
        for translation_path, translation_dict in file_dict['translations'].items():
            lang_id = translation_dict['language_id']
            result.setdefault(lang_id, {}).setdefault('translated_files', []).append({ 'base': base_path, 'translation': translation_path, 'repo': repo })
    
    # Get untranslated files
    
    for lang_id, d in result.items():
        translated_bases = list(map(lambda file: file['base'], d['translated_files']))
        for b in base_files:
            if b['base'] not in translated_bases:
                d.setdefault('untranslated_files', []).append(b)
    
    # Return
    return result

def analyze_localization_files(files):

    """
    
    Notes on is_ok_count:
    
    The is_ok_count is the number of exclamation marks in `!IS_OK` comment next to a kv-pair in the .strings/.js file. 
    People can add the `!IS_OK` comment / add exclamation marks to indicate that a translation is currently ok and doesn't have to be changed.
    At time of writing, is_ok_count is used for 2 things in the code:
        1. When the is_ok_count increases for a kv-pair in a commit, that's treated as a `change` to the kv-pair in `get_latest_change_for_translation_keys()`.
            This should behave well in all scenarios. E.g. when is_ok_count increases the kv-pair will not be considered outdated. But when the base value changes afterwards, the translation will be considered outdated again.
        2. When the is_ok_count for a kv-pair is greater 0, then we filter that kv-pair from the 'unchanged_translations' and the 'empty_translations'.
            Important consideration why this makes sense: 
                The only time a translation would 'accidentally' be exactly the same as the base (unchanged) is if the translation has been generated by Xcode and never been touched by a human.
                I'm not totally sure if this behaviour also makes sense for 'empty_translations'.
    
    Structure of the analysis result: (at time of writing) (This takes the input file and just fills in stuff)
    [
        {
            'base': '<base_file_path>',
            'repo': git.Repo()
            'translations': {
                <translation_file_path>: {
                    'missing_translations':     [{ 'key': <translation_key>, 'value': <ui_text> }, ...],
                    'superfluous_translations': [{ 'key': <translation_key>, 'value': <ui_text> }, ...],
                    'unchanged_translations':   [{ 'key': <translation_key>, 'value': <ui_text> }, ...],
                    'empty_translations':       [{ 'key': <translation_key>, 'value': <ui_text>, 'base_value': <ui_text>}, ...],
                    'outdated_translations': {
                        '<translation_key>': {
                            'latest_base_change': {
                                "commit": git.Commit(<commit_of_lastest_change>),
                                "before": { "text": "<ui_text>", "is_ok_count": <int> },
                                "after": { "text": "<ui_text>", "is_ok_count": <int> },
                            },
                            'latest_translation_change': {
                                "commit": git.Commit(<commit_of_lastest_change>),
                                "before": { "text": "<ui_text>", "is_ok_count": <int> },
                                "after": { "text": "<ui_text>", "is_ok_count": <int> },
                            }
                        },
                        '<translation_key>': {
                            ...
                        },
                        ...
                    },
                    'outdating_commits': {
                        'latest_translation_change': git.Commit(),
                        'newer_base_changes': [<commits_to_base_file_after_the_latest_commit_to_translation_file>]
                    }
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
    print(f'Analyzing localization file content...')
    
    # Get 'outdating commits'
    #   This is a more primitive method than analyzing the changes to translation keys. Should only be relevant for files that don't have translation keys
    
    print(f'  Analyzing outdating commits...')
    
    for file_dict in files:
        
        base_file = file_dict['base']
        repo = file_dict['repo']
        
        for translation_file, translation_dict in file_dict['translations'].items():
            
            translation_change_iterator = iter_content_changes(translation_file, repo) # repo.iter_commits(paths=translation_file, **{'max-count': 1} ) # max-count is passed along to `git rev-list` command-line-arg
            last_translation_change = next(translation_change_iterator)
            
            outdating_commits = []
            
            base_change_iterator = iter_content_changes(base_file, repo) # repo.iter_commits(paths=translation_file)
            
            for base_change in base_change_iterator:
                if not is_predecessor_or_equal(base_change, last_translation_change):
                    outdating_commits.append(base_change)
                else:
                    break
            
            if len(outdating_commits) > 0:
                translation_dict['outdating_commits'] = {
                    'latest_translation_change': last_translation_change,
                    'newer_base_changes': outdating_commits
                }
    
    
    # Log
    print(f'  Analyzing changes to translation keys and values...')
    
    # Analyze changes to translation keys
    for file_dict in files:
        
        # Get base file info
        base_file_path = file_dict['base']
        _, base_file_type = os.path.splitext(base_file_path)
        
        # Skip
        if not (base_file_type == '.js' or base_file_type == '.strings' or base_file_type == '.xib' or base_file_type == '.storyboard'):
            continue
        
        # Log
        print(f'    Processing base translation at {base_file_path}...')
        
        # Get repo
        repo = file_dict['repo']
        
        # Get basefile kv-pairs
        base_keys_and_values = extract_translation_keys_and_values_from_file(file_dict['base'])
        
        # Get IB placeholders
        # Note: 
        #  In IB files we mark placeholders that will not be shown to the user and don't need to be translated by surrounding them with <angle brackets>.
        #  This code makes it so the analysis ignores these placeholders
        ib_placeholders = dict()
        if base_file_type == '.xib' or base_file_type == '.storyboard':
            for key, value in base_keys_and_values.items():
                text = value['value']['text']
                if len(text) >= 2 and text[0] == '<' and text[-1] == '>':
                    ib_placeholders[key] = value
        
        # Remove IB placeholders from main kv-pairs
        for k in ib_placeholders.keys():
            base_keys_and_values.pop(k, 'None')
        
        # Extract keys from kv-pairs
        if base_keys_and_values == None: continue
        base_keys = set(base_keys_and_values.keys())
        
        # For each key in the base file, get the commit, when it last changed
        latest_base_changes = get_latest_change_for_translation_keys(base_keys, base_file_path, repo)      
        
        # Debug
        # if "LicenseSheetController" in base_file_path:
        #     print(f"Licensesheet latest changes - {latest_base_changes}")
        
        # Iterate translations
        for translation_file_path, translation_dict in file_dict['translations'].items():
            
            # Log
            print(f'      Processing translation of {os.path.basename(base_file_path)} at {translation_file_path}...')
            print(f'        Find translation keys and values...')
            
            # Find kv-pairs in translation file
            translation_keys_and_values = extract_translation_keys_and_values_from_file(translation_file_path)
            
            # Remove IB placeholders
            for k in ib_placeholders.keys():
                translation_keys_and_values.pop(k, 'None')
            
            # Extract keys from kv_pairs
            translation_keys = set(translation_keys_and_values.keys())
            
            print(f'        Check missing/superfluous keys...')
            
            # Do set operations
            missing_keys = base_keys.difference(translation_keys)
            superfluous_keys = translation_keys.difference(base_keys)
            common_keys = base_keys.intersection(translation_keys)
            
            
            # DEBUG
            # print(f"missing: {missing_keys}, super: {superfluous_keys}, common: {common_keys}, base: {base_keys}, translation: {translation_keys}, latest_base_changes: {latest_base_changes}")
            
            # Get & attach missing / superfluous translations
            #   Note: missing / superfluous can't be marked as !IS_OK
            
            missing_translations        = list(map(lambda k: {'key': k, 'value': base_keys_and_values[k]['value']['text']}, missing_keys))
            superfluous_translations    = list(map(lambda k: {'key': k, 'value': translation_keys_and_values[k]['value']['text']}, superfluous_keys))
            translation_dict['missing_translations'] = missing_translations
            translation_dict['superfluous_translations'] = superfluous_translations
            
            # Check & attach unchanged & empty translations
            # Note on `<>` checks: 
            #   I saw we used `<>` to signal empty for kv-pairs pairs in `.strings` file that are actually defined in .stringsdict instead, maybe also other places. That's why we consider `<>` an empty string here.
            #   Not sure if use of `<>` is the best idea. Why not just use actually empty string? Maybe bartycrouch complained or something?
            
            
            print(f'        Check unchanged & empty translations...')
            
            unchanged_translations = []
            empty_translations = []
            for k in common_keys:
                
                b = base_keys_and_values[k]['value']
                t = translation_keys_and_values[k]['value']
                
                is_ok = t['is_ok_count'] > 0
                is_equal = b['text'] == t['text']
                b_is_empty = len(b['text']) == 0 or b['text'] == '<>'
                t_is_empty = len(t['text']) == 0 or t['text'] == '<>'
                both_are_empty = b_is_empty and t_is_empty
                
                if is_equal and not both_are_empty and not is_ok:
                    unchanged_translations.append({'key': k, 'value': t['text']})
                if not b_is_empty and t_is_empty and not is_ok:
                    empty_translations.append({'key': k, 'value': t['text'], 'base_value': b['text']})
            
            translation_dict['unchanged_translations'] = unchanged_translations
            translation_dict['empty_translations'] = empty_translations
            
            # Log
            print(f'        Analyze when keys last changed...')
            
            # Check common keys if they are outdated.
            
            # For each key, get the commit when it last changed
            latest_translation_changes = get_latest_change_for_translation_keys(common_keys, translation_file_path, repo)
            
  
            
            # Log
            print(f'        Check if last modification was before base for each key ...')
            
            # Compare time of latest change for each key between base file and translation file
            for k in common_keys:
                
                base_commit = latest_base_changes[k]['commit']
                translation_commit  = latest_translation_changes[k]['commit']
                
                is_outdated = not is_predecessor_or_equal(base_commit, translation_commit)
                
                # DEBUG
                # if 'de.lproj/Localizable.strings' in translation_file_path and 'trial-counter.active' in k:
                #     print(f"DEBUG:\n\nlatest_base: {base_commit}, latest_trans: {translation_commit}, is_outdated: {is_outdated}")
                
                # Special cases
                # Notes: 
                # - We first created `Localizable.strings` in German and then later translated it to English in commit d5aeb1195023b7bcea983d112ed0929b07311108 on 06.09.2022 [We could also use 9d385e6 on 22.09.2022 to spare us a few more `!IS_OK`s but it's whatever.]
                #   This special case is to prevent those German strings from being detected as outdated.

                if is_mmf_repo(repo) and os.path.basename(base_file_path) in ('Localizable.strings'):
                    become_base_commit = repo.commit('d5aeb1195023b7bcea983d112ed0929b07311108') # The commit where the English file became the base
                    if is_predecessor_or_equal(base_commit, become_base_commit):
                        is_outdated = False
                
                # DEBUG
                # if 'de.lproj/Localizable.strings' in translation_file_path and 'trial-counter.active' in k:
                #     print(f"DEBUG:\n\nlatest_base: {base_commit}, latest_trans: {translation_commit}, is_outdated: {is_outdated}")
                #     print(f"latest_base_change: {base_file_path}, change: {base_commit}")
                #     print(f"translated_change: {translation_file_path}, change: {translation_commit}")
                
                if is_outdated:
                    translation_dict.setdefault('outdated_translations', {})[k] = { 'latest_base_change': latest_base_changes[k], 'latest_translation_change': latest_translation_changes[k] }    
    
    # Return
    return files

#
# Change analysis
#

def get_latest_change_for_translation_keys(wanted_keys, file_path, git_repo):
    
    """
    
    Note: If the is_ok_count goes up, that commit will also be treated as a 'change' to the value even if the translation text doesn't change. Little confusing but it should work.
    
    Structure of result:
    {
        "<translation_key>": {
            "commit": git.Commit(<commit_of_lastest_change>),
            "before": { "text": "<ui_text>", "is_ok_count": <int> },
            "after": { "text": "<ui_text>", "is_ok_count": <int> },
        }, 
        "<translation_key>": {
            ...
        },
        ...
    }
    """
    
    # Debug
    # print(f"Getting latest changes per key for file {file_path}")
    
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
                
                added = changes.get('added', None)
                deleted = changes.get('deleted', None)
                added_ok_count = added['is_ok_count'] if added else 0
                deleted_ok_count = deleted['is_ok_count'] if deleted else 0
                added_text = added['text'] if added else None
                deleted_text = deleted['text'] if deleted else None
                
                if added_ok_count > deleted_ok_count or added_text != deleted_text:
                    new_entry = { 'commit': commit, 'before': deleted, 'after': added }
                    result[key] = new_entry
                    wanted_keys.remove(key)    
    
    if t == 'strings':
        
        # Get commits
        commits = get_commits_follow_renames(file_path, git_repo)
        
        # DEBUG
        # if 'de' in file_path:
        #     print(f"DEBUG - commits on de file: {commits}")
        
        for i, commit in enumerate(commits): # enumerate(git_repo.iter_commits(paths=file_path, reverse=False)):
            
            # Break
            if len(wanted_keys) == 0:
                break
            
            # Get diff string
            #   Run git command 
            #   - For getting additions and deletions of the commit compared to its parent
            #   - I tried to do this with gitpython but nothing worked, maybe I should stop using gitpython altogether?
            diff_string = runCLT(f"git diff -U0 {commit['hash']}^..{commit['hash']} -- {commit['path']} {commit['previous_path'] or ''}", cwd=repo_root).stdout
            
            # Parse diff
            parse_diff_and_update_state(diff_string, git_repo.commit(commit['hash']), result, wanted_keys)
            
    elif t == 'IB':
        
        # Notes:
        # - This seems to be by far the slowest part of the script. It's still fast enough, but maybe look into optimizing.
        # -     Possible sources of slowness: subprocess calls (I read that command is faster), file-creations/reads/writes, complex git commands.
        
        commits = get_commits_follow_renames(file_path, git_repo) # list(git_repo.iter_commits(paths=file_path, reverse=False))
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

                hash = commit['hash']
                path = commit['path']
                
                path_relative = path # `git show` breaks with absolute paths, but paths from get_commits_follow_renames() are already relative
                
                path_for_content_at_this_commit = create_temp_file(suffix=file_type)
                git_show_cmd = f"git show {hash}:'{path_relative}' > {path_for_content_at_this_commit}"
                runCLT(git_show_cmd, cwd=repo_root)
                strings_file_path = extract_strings_from_IB_file_to_temp_file(path_for_content_at_this_commit)
                
                # Debug
                # if "LicenseSheetController" in file_path:
                    # print(f"Licensesheet diff - {diff_string}")
                    # print(f"Licensesheet debug - repo root: {repo_root}, cmd: {git_show_cmd}, result {read_tempfile(path_for_content_at_this_commit)}, cltResult: {cltResult}")
                
            if i != 0: 
                
                # Get diff
                
                # Notes: 
                #  We skip the first iteration. That's because, on the first iteration,
                #  there's no `last_strings_file_path` to diff against.
                #  To 'make up' for this lack of diff on the first iteration, we have the extra 'None' commit. 
                #  Kind of confusing but it should work.
                
                # Validate
                assert last_strings_file_path != ''
                
                # Get diff string
                diff_string = runCLT(f"git diff -U0 --no-index -- {strings_file_path} {last_strings_file_path}", cwd=repo_root).stdout
                
                # Parse diff, update state * record result
                result_commit = git_repo.commit(commits[i-1]['hash']) if commits[i-1] else None
                parse_diff_and_update_state(diff_string, result_commit, result, wanted_keys)
                
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

def iter_content_changes(file_path_arg, repo):

    # Iterate commits that actually changed the content of `file_path`. 
    #   We do this to exclude commits where the file was just renamed and the content didn't change.
    #   This is used to determine outdating commits. Maybe we should put this in line with that instead of having a separate function?

    # Prepare
    
    repo_root = repo.working_tree_dir
    file_path_relative = os.path.relpath(file_path_arg, repo_root) # `git show` breaks with absolute paths
    
    # Get changes
    
    changes = get_commits_follow_renames(file_path_arg, repo)
    
    assert len(changes) > 0
    
    # Loop changes and return changes where content actually changed.
    
    last_hash = changes[0]['hash']
    last_content = runCLT(f"git show {last_hash}:'{file_path_relative}'", cwd=repo_root).stdout
    
    if len(changes) > 1:
        for commit in changes[1:]:
            
            hash = commit['hash']
            path = commit['path']
            
            content = runCLT(f"git show {hash}:'{path}'", cwd=repo_root).stdout
            
            if content != last_content:
                yield repo.commit(last_hash)
        
            last_content = content
            last_hash = hash
    
    yield repo.commit(changes[-1]['hash'])
    
def get_commits_follow_renames(file_path_arg, repo, similarity_threshold=80):

    """
    Returns a list of commits that changed the file at `file_path`. The list follows the changes through renames of the file. 
        For each commit it also returns what the file was names at that point and some other info.

        Note that all paths in the output of this are relative to the repo root. 
            ! If you call os.path.relpath() on them, that will break things

    Structure of output:
    [
        {
            'hash':             <commit_hash>, 
            'path':             <path_of_file_at_this_commit>,     
            'previous_path':    <path_of_file_before_rename>,      # Is None unless the files has been renamed this commit
            "status_code":      <git_file_status_code>,            # e.g. M for modified, A for added, R for renamed, etc.
            'similarity':       <git_similarity_index>,            # How similar the file is after a rename in %. Is 100 if the file was just renamed and the content didn't change.
        }, 
        ...
    ]
    
    Notes on similarity_threshold:
    - The default git similarity threshold in git is 50%, but that made it so some strings files that were added for a new language were marked as copies
      E.g. When App/UI/LicenseSheet/zh-Hans.lproj/LicenseSheetController.strings was added in aadba972bfccf4f3a12b8717014cb07708b3e2f7, 
        it had 64% similarity with the German version, even though it was fully translated.
        Between Korean and Chinese, I saw 76% similarity for 2 fully translated files.
        80% as the threshold seems to work at this moment.
      The high similarity between translated files is probably because all the comment lines and all the keys are the same between all languages in `.strings.` files.
      Maybe we should apply different similarity thresholds depending on file type.
    """

    # TODO: Update these comments.
    # Use `git log --follow` to get a list of `git.Commit()`s that changed a file, while following file-renames.
    # Notes: 
    # - The old way we iterated through commits is `repo.iter_commits(paths=file_path)`, but that doesn't follow renames. I hope that switching to this doesn't cause problems.
    # - UDPATE: RENAMES DON'T WORK YET. neither `git show` nor `git diff` can follow renames when called on a specific file. 
    #   `git diff` can detect renames but only when called on the whole repo not when a path is specified. We could probably do some manual parsing to make this work but that't tooo hard for now. 
    #   If we can't get diffs between renames, then we don't need to iterate through commits on files through renames either. Hence this function is unnecessary.
    #   Tracking changes through renames is but a dream for us at this point. So I guess we'll just have to abide by this principle: 
    #       
    #       Don't rename files unless all the issues detected by this script are resolved! I think then everything should be sound.
    #
    #   TODO: Remove this renames stuff, since it doesn't work 
    
    # Just use iter_commits since we can't track renames anyways
    # return list(repo.iter_commits(paths=file_path))
    
    # Preprocess
    repo_path = repo.working_tree_dir
    file_path = file_path_arg # os.path.relpath(file_path_arg, repo_path) # `git show` breaks with absolute paths, not sure if this is necessary for `git log`
    
    # Call git log
    
    sep= "\n@@@COMMIT@@@\n"
    cmd = f"git -C {repo_path} log --follow -M{str(similarity_threshold)}% --name-status --format='{sep}%H' -- {file_path}"
    sub_return = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, shell=True, cwd=repo.working_tree_dir)
    if sub_return.returncode != 0:
        raise Exception("Git command failed: " + sub_return.stderr)

    # Parse the output
    
    result = []
    
    commit_strs = sub_return.stdout.split(sep)[1:]
    
    for commit_str in commit_strs:
        
        commit_lines = commit_str.splitlines()
        
        commit_hash = commit_lines[0]
        file_status_lines = commit_lines[1:]
        
        status_list = []
        for status_line in file_status_lines:
            status = parse_git_status_line(status_line)
            if status: status_list.append(status)
        
        assert len(status_list) == 1
        status = status_list[0]
        
        # Validate
        # Status C (copy) does sometimes happen in the repo history, for example in d48bd4c991136c3b37cf383f86aeb6db05a52194, the korean Localizable.strings is just a copy of the english version, and then later it's changed.
        
        if status['code'] == 'C':
            print(f"INFO: Found copy status in commit history at commit {commit_hash}. Status: {status}")
                  
        assert status['code'] != 'D', "If the file has been deleted, why do we want to track changes to it?"
        assert status['code'] != 'U', "Unmerged files shouldn't show up when tracking the history of a file I think."
        
        current_path = status['file2'] or status['file1']
        previous_path = status['file1'] if status['file2'] else None
        
        result.append({'hash': commit_hash, 'path': current_path, 'previous_path': previous_path, "status_code": status['code'], 'similarity': status['similarity']})
    

    # Return
    
    return result


def parse_git_status_line(line):
    
    
    """
    Regular expression pattern to match the status line
    Test strings:
        M	App/UI/New UI/Main+TabView/Base.lproj/Main.storyboard
        R100	App/UI/New UI/Main+TabView/Base.lproj/Main.storyboard	App/UI/Main/Base.lproj/Main.storyboard
    """
    pattern = r"^(A|M|D|T|U|X)\t(.+)$|^(R|C)(\d+)\t(.+)\t(.+)$"
    match = re.match(pattern, line)

    if match:
        # Extracting data based on the matched groups
        status = match.group(1) or match.group(3)
        similarity = match.group(4) if match.group(4) else None
        file1 = match.group(2) or match.group(5)
        file2 = match.group(6) if match.group(6) else None

        if similarity: similarity = int(similarity)

        return {
            "code": status,
            "similarity": similarity,
            "file1": file1,
            "file2": file2
        }
    else:
        return None
    
    
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

def is_predecessor_or_equal(potential_predecessor_commit, commit):
    
    # Check which commit is 'earlier'. Works kind of like potential_predecessor_commit <= commit (returns true for equality)
    # Not totally sure what we're doing here. 
    #   - First, we were checking for ancestry with `git merge-base``, but that slowed the whole script down a lot (maybe we could've alleviated that by changing runCLT? We have some weird options there.) (We also tried `rev-list --is-ancestor`, but it didn't help.)
    #   - Then we updated to just comparing the commit date. I think it might make less sense than checking ancestry, and might lead to wrong results, maybe? But currently it seems to work okay and is much faster. 
    #   - Not sure if `committed_date` or `authored_date` is better. Both seem to give the same results atm.
        
    return potential_predecessor_commit.committed_date <= commit.committed_date
    # return runCLT(f"git rev-list --is-ancestor {potential_predecessor_commit.hexsha} {commit.hexsha}").returncode == 0
    # return runCLT(f"git merge-base --is-ancestor {potential_predecessor_commit.hexsha} {commit.hexsha}").returncode == 0

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
# Find files
#

def find_localization_files(repo_root, website_root):
    
    """
    Find localization files
    
    Structure of the result:
    [
        {  
            "base": "<path_to_base_localization_file>",
            "repo": git.Repo(<mac-mouse-fix|mac-mouse-fix-website>),
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
    
    # Get repos
    mmf_repo = git.Repo(repo_root)
    website_repo = git.Repo(website_root)
    assert mmf_repo != None and website_repo != None
    
    # Get result
        
    result = []
    
    # Append website basefile
    result.append({ 'base': website_root + '/' + 'locales/en-US.js', 'repo': website_repo, 'basetype': 'nuxt'})
    
    # Appen markdown base_files
    for root, dirs, files in os.walk(markdown_dir):
        is_en_folder = 'en-US' in os.path.basename(root)
        if is_en_folder:
            files_absolute = map(lambda file: root + '/' + file, files)
            for b in files_absolute:
                # Validate
                _, extension = os.path.splitext(b)
                assert extension == '.md', f'Folder at {b}, contained file with extension {extension}'
                # Append markdown file
                result.append({ 'base': b, 'repo': mmf_repo, 'basetype': 'markdown' })
        
    # Append Xcode base files 
    #   Note: We do this last because in the analysis we iterate through the `result` dict in insertion order, and analyzing the IB stuff is the slowest. So doing this last makes debugging more convenient.
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
                # Append Xcode file
                result.append({ 'base': b, 'repo': mmf_repo, 'basetype': type })
    
    # Find translated files
    
    for e in result:
        
        base_path = e['base']
        basetype = e['basetype']
        del e['basetype']
        
        translations = {}
        
        # Get dir which contains all the translation files
        translation_root = ''
        if basetype == 'nuxt':
            translation_root = os.path.dirname(base_path) # Parent of basefile
        else:
            translation_root = os.path.dirname(os.path.dirname(base_path)) # Grandparent of basefile
        
        for root, dirs, files in os.walk(translation_root):
            
            # print(f"Finding translations in translation root {translation_root} --- root: {root}, dirs: {dirs}, files: {files}")
            
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
                
                # Skip unrecognized files
                if basetype == 'IB' or basetype == 'strings':
                    if extension not in ['.xib', '.storyboard', '.strings', '.stringsdict']:
                        print(f"  Skipping file {f} because it has an invalid extension. It was found while searching for translation files in {translation_root}")
                        continue
                if basetype == 'markdown':
                    if extension not in ['.md']:
                        print(f"  Skipping file {f} because it has an invalid extension. It was found while searching for translation files in {translation_root}")
                        continue
                if basetype == 'nuxt':
                    if extension not in ['.js']:
                        print(f"  Skipping file {f} because it has an invalid extension. It was found while searching for translation files in {translation_root}")
                        continue
                
                # Combine info
                
                absolute_f = root + '/' + f
                filename_matches = filename == base_filename
                extension_matches = extension == base_extension
                is_base_file = absolute_f == base_path
                
                # Append
                
                do_append = False
                
                if not is_base_file:    
                    if basetype == 'nuxt':
                        if extension_matches: do_append = True
                    elif basetype == 'markdown':
                        if extension_matches and filename_matches: do_append = True
                    elif basetype == 'IB':
                        if filename_matches: do_append = True
                    elif basetype == 'strings':
                        if extension_matches and filename_matches: do_append = True
                    else:
                        assert False
                
                if do_append:
                    
                    # Get language id
                    language_id = ''
                    if basetype == 'nuxt':
                        language_id = filename
                    else:
                        language_id, _ = os.path.splitext(os.path.basename(root)) # Parent folder name contains language_id. E.g. `en.lproj`
                    
                    # Append
                    translations[absolute_f] = { "language_id": language_id }
        
        # Append
        e['translations'] = translations
    
    return result

#
# General Helpers
#

def is_mmf_repo(git_repo):
    repo_root = git_repo.working_tree_dir
    if os.path.basename(repo_root) == 'mac-mouse-fix':
        return True
    return False

def is_website_repo(git_repo):
    repo_root = git_repo.working_tree_dir
    if os.path.basename(repo_root) == 'mac-mouse-fix-website':
        return True
    return False

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

#
# Call main
#
if __name__ == "__main__": 
    main()