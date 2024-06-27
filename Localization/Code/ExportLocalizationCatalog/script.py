#
# Imports 
# 

import tempfile
import os
import sys
import json
import shutil
import glob
from collections import defaultdict
from collections import namedtuple
from pprint import pprint
import argparse
import zipfile
import babel

#
# Import functions from ../Shared folder
#

import shared

# Print sys.path to debug
#   - This needs to contain the ../Shared folder in oder for the import and VSCode completions to work properly
#   - We add the ../Shared folder to the path through the .env file at the project root.

print("Current sys.path:")
for p in sys.path:
    print(p)

# Note about vvv: Since we add the ../Shared folder to the python env inside the .env file (at the project root), we don't need the code below vvv any more. Using the .env file has the benefit that VSCode completions work with it.

# code_dir = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
# if code_dir not in sys.path:
#     sys.path.append(code_dir)
# from Shared import shared
    
#    
# Constants
#
    
#
# Define main
#
    
def main():
    
    # Inital free line to make stuff nicer
    print("")
    
    # Parse args
    parser = argparse.ArgumentParser()
    parser.add_argument('--api_key', required=False, help="The API key is used to interact with GitHub || You can also set the api key to the API_KEY env variable in the VSCode Terminal || To find the API key, see Apple Note 'MMF Localization Script Access Token'")
    args = parser.parse_args()
    
    # Get api_key
    print("Getting API key ...\n")
    no_api_key = args.api_key == None or len(args.api_key) == 0
    if no_api_key:
        args.api_key = os.getenv("API_KEY")
    no_api_key = args.api_key == None or len(args.api_key) == 0
    
    if no_api_key:
        print("No API key provided\n")
    else:
        print(f"Working with API_KEY: {args.api_key}")
    
    # Get locales for this project
    print(f"Extracting locales from .xcodeproject ...")
    
    pbxproject_json = json.loads(shared.runCLT(f"plutil -convert json -r -o - Mouse\ Fix.xcodeproj/project.pbxproj").stdout) # -r puts linebreaks into the json which is unnecessary here.
    development_locale = None
    locales = None
    for obj in pbxproject_json['objects'].values():
        if obj['isa'] == 'PBXProject':
            locales = obj['knownRegions']
            development_locale = obj['developmentRegion']
            break
    
    assert(development_locale != None and locales != None and len(locales) >= 1)
    
    print("")
    
    # Filter locales
    print(f"Filtering out Base and development locales ...\n")
    locales = [l for l in locales if l != development_locale and l != 'Base']
    print(f"Filtered locales: { locales }")
    print("")
    
    # Load all .xcstrings files
    print(f"Loading all .xcstring files ...\n")
    xcstring_objects = []
    xcstring_filenames = glob.glob("**/*.xcstrings", recursive=True)
    for f in xcstring_filenames:
        with open(f, 'r') as content:
            xcstring_objects.append(json.load(content))
    print(f".xcstring file paths: { json.dumps(xcstring_filenames, indent=2) }\n")
    
    
    # Create an overview of how many times each translation state appears for each language
    print(f"Determining localization state overview ...\n")
    localization_state_overview = defaultdict(lambda: defaultdict(lambda: 0))
    for xcstring_object in xcstring_objects:
        for key, string_dict in xcstring_object['strings'].items():
            
            for locale in locales:
                
                s = string_dict.get('localizations', {}).get(locale, {}).get('stringUnit', {}).get('state', 'mmf_indeterminate')
                assert(s == 'new' or s == 'needs_review' or s == 'translated' or s == 'stale' or s == 'mmf_indeterminate')        
                
                localization_state_overview[locale][s] += 1
    
    localization_state_overview = json.loads(json.dumps(localization_state_overview)) # Convert nested defaultdict to normal dict - which prints in a pretty way
    
    print(f"Localization state overview: \n")
    pprint(localization_state_overview)
    print("")
    
    # Get translation progress for each language
    #   Notes: 
    #   - Based on my testing, this seems to be accurate except that it didn't catch the missing translations for the Info.plist file. That's because the info.plist file doesn't have an .xcstrings file at the moment but we can add one.
    print(f"Determining localization progress ...\n")
    localization_progress = {}
    for locale, states in localization_state_overview.items():
        translated_count = states.get('translated', 0)
        to_translate_count = states.get('translated', 0) + states.get('needs_review', 0) + states.get('new', 0) + states.get('mmf_indeterminate', 0) # Note how we're ignoring stale strings here. (Stale means that the kv-pair is superfluous and doesn't occur in the base file/source code file afaik, therefore it's not part of 'to_translate' set)
        localization_progress[locale] = {'translated': translated_count, 'to_translate': to_translate_count, 'percentage': translated_count/to_translate_count}
    print(f"Localization progress: {json.dumps(localization_progress, indent=2)}\n")    
    
    # Get a temp dir to store exported .xcloc files to
    temp_dir = tempfile.gettempdir()
    xcloc_dir = os.path.join(temp_dir, 'mmf-xcloc-export')
    shutil.rmtree(xcloc_dir)
    os.mkdir(xcloc_dir)
    
    # Export .xcloc file for each locale
    print(f"Exporting .xcloc files for locales ...\n")
    locale_args = ' '.join([ '-exportLanguage ' + l for l in locales ])
    shared.runCLT(f"xcodebuild -exportLocalizations -localizationPath { xcloc_dir } { locale_args }")
    print(f"Exported .xcloc files to {xcloc_dir}\n")
    
    # Zipping up .xcloc files
    
    print(f"Zipping up .xcloc files ...\n")
    zip_files = {}
    for file_path in glob.glob(f'{xcloc_dir}/*.xcloc'):
        
        file_name = os.path.basename(file_path)
        file_name_stem = os.path.splitext(file_name)[0]
        zip_file_path = os.path.join(xcloc_dir, f'{file_name_stem}.zip')
        zip_file_name = os.path.basename(zip_file_path)
        
        if os.path.exists(zip_file_path):
            rm_result = shared.runCLT(f'rm -R {zip_file_path}') # We first remove any existing zip_file, because otherwise the `zip` CLT will combine the existing archive with the new data we're archiving which is weird. (If I understand the `zip` man correctly`)
            print(f'Zip file of same name already existed. Calling rm on the zip_file returned: { shared.clt_result_description(rm_result) }')
            
        zip_result = shared.runCLT(f'zip -r {zip_file_name} {file_name}', cwd=xcloc_dir) # We need to set the cwd (current working directory) like this, if we use abslute path to the zip_file and xcloc file, then the `zip` clt will recreate the whole path from our system root inside the zip archive. Not sure why.
        print(f'zip clt returned: { shared.clt_result_description(zip_result) }')
        
        with open(zip_file_path, 'rb') as zip_file:
            # Load the zip data
            zip_file_content = zip_file.read()
            # Store the data in the GitHub API format
            zip_files[zip_file_name] = zip_file_content
            
    print(f"Finished zipping up .xcloc files.\n")
    
    print(f"Uploading to GitHub ...\n")
    
    # Find GitHub Release
    response = shared.github_releases_get_release_with_tag(args.api_key, 'noah-nuebling/mac-mouse-fix-localization-file-hosting', 'arbitrary-tag') # arbitrary-tag is the tag of the release we want to use, so it is not, in fact, arbitrary
    release = response.json()
    print(f"Found release { release['name'] }, received response: { shared.response_description(response) }")
    
    # Delete all Assets 
    #   from GitHub Release
    for asset in release['assets']:
        response = shared.github_releases_delete_asset(args.api_key, 'noah-nuebling/mac-mouse-fix-localization-file-hosting', asset['id'])
        print(f"Deleted asset { asset['name'] }, received response: { shared.response_description(response) }")
    
    # Upload new Assets
    #   to GitHub Release
    
    download_urls = {}
    for zip_file_name, zip_file_content in zip_files.items():
        
        response = shared.github_releases_upload_asset(args.api_key, 'noah-nuebling/mac-mouse-fix-localization-file-hosting', release['id'], zip_file_name, zip_file_content)        
        download_urls[zip_file_name] = response.json()['browser_download_url']
        
        print(f"Uploaded asset { zip_file_name }, received response: { shared.response_description(response) }")
        
    print(f"Finshed Uploading to GitHub. Download urls: { json.dumps(download_urls, indent=2) }")
    
    # Create markdown
    new_discussion_body = f"""    
# This 

is a

*test*

## Localization Files

"""
    
    # Fill in data into markdown table
    
    md_table = ""
    
    md_table += """\
| Language | Translation Files | Completeness |
|:--- |:---:| ---:|
"""

    for locale in sorted(locales, key=lambda l: shared.language_tag_to_language_name(l)): # Sort the locales by language name (Alphabetically)
        
        progress = localization_progress[locale]
        progress_percentage = int(100 * progress['percentage'])
        download_name = 'Download'
        download_url = download_urls[f'{locale}.zip']
        
        emoji_flag = shared.language_tag_to_flag_emoji(locale)
        language_name = shared.language_tag_to_language_name(locale)
        
        # Note: We're adding the <br>'s to make the rows a little higher. This makes it less visible tha the shields.io badge isn't vertically aligned. Best solution I could come up with.
        
        entry = f"""\
| {emoji_flag} {language_name} ({locale}) | [{download_name}]({download_url}) | ![Static Badge](https://img.shields.io/badge/{progress_percentage}%25-Translated-gray?style=flat&labelColor={'%23aaaaaa' if progress_percentage < 100 else 'brightgreen'}) |
"""
        md_table += entry
    
    new_discussion_body += md_table
    
    # Escape markdown
    new_discussion_body = shared.escape_for_upload(new_discussion_body)


    
    if no_api_key:
        
        print(f"No API key provided, can't upload result to GitHub")
    
    else:
    
        # Find discussion #1022
        find_discussion_result = shared.github_graphql_request(args.api_key, """      
                                                                                           
query {
  repository(owner: "noah-nuebling", name: "mac-mouse-fix") {
    discussion(number: 1022) {
      id
      url
    }
  }
}
""")
        discussion_id = find_discussion_result['data']['repository']['discussion']['id']
        discussion_url = find_discussion_result['data']['repository']['discussion']['url']
    
        # Mutate the discussion body
        mutate_discussion_result = shared.github_graphql_request(args.api_key, f"""
                                  
mutation {{
    updateDiscussion(input: {{discussionId: "{discussion_id}", body: "{new_discussion_body}"}}) {{
        clientMutationId
    }}
}}
""")
    
        # Check for success
        print(f" Mutate discussion result:\n{json.dumps(mutate_discussion_result, indent=2)}")
        print(f" Discussion available at: { discussion_url }")
    
    
    
    
#
# Call main
#

if __name__ == "__main__":
    main()