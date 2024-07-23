
"""

This scripts creates .xcloc files for the MMF project and publishes them on GitHub.

"""

#
# Imports
# 

import tempfile
import os
import json
import shutil
import glob
from collections import namedtuple
from pprint import pprint
import argparse

#
# Import functions from ../Shared folder
#

import mfutils
import mflocales
import mfgithub

# Print sys.path to debug
#   - This needs to contain the ../Shared folder in oder for the import and VSCode completions to work properly
#   - We add the ../Shared folder to the path through the .env file at the project root.

# print("Current sys.path:")
# for p in sys.path:
#     print(p)

# Note about vvv: Since we add the ../Shared folder to the python env inside the .env file (at the project root), we don't need the code below vvv any more. Using the .env file has the benefit that VSCode completions work with it.

# code_dir = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
# if code_dir not in sys.path:
#     sys.path.append(code_dir)
# from Shared import shared
    
#    
# Constants
#

website_repo = './../mac-mouse-fix-website'

#
# Define main
#
    
def main():
    
    # Inital free line to make stuff look nicer
    print("")
    
    # Get repo name
    repo_path = os.getcwd()
    repo_name = os.path.basename(repo_path)
    
    # Validate
    assert repo_name == 'mac-mouse-fix' and repo_name != 'mac-mouse-fix-website', 'This script should be ran in the mac-mouse-fix repo'
    assert os.path.isdir(website_repo), f'To run this script, the mac-mouse-fix-website repo should be placed at {website_repo} relative to the mac-mouse-fix repo.'
    
    # Parse args
    parser = argparse.ArgumentParser()
    parser.add_argument('--api_key', required=False, default=os.getenv("GH_API_KEY"), help="The API key is used to interact with GitHub || You can also set the api key to the GH_API_KEY env variable (in the VSCode Terminal to use with VSCode) || To find the API key, see Apple Note 'MMF Localization Script Access Token'")
    args = parser.parse_args()
    
    # Check api_key
    no_api_key = args.api_key == None or len(args.api_key) == 0
    if not no_api_key:
        print(f"Working with api_key: ")
    else:
        print("No api key provided\n")
        parser.print_help()
        exit(1)
    
    # Store stuff
    #   (To validate locales between repos)
    
    previous_xcodeproj_path = None
    previous_repo_locales = None
    
    # Store more stuff
    #   (To get localization progress)
    xcstring_objects_all_repos = []
    localization_progess_all_repos = None
    translation_locales_all_repos = None
    
    # Create temp_dir
    temp_dir = tempfile.gettempdir() + '/mmf-uploadstrings'
    if os.path.isdir(temp_dir):
        shutil.rmtree(temp_dir)
    os.mkdir(temp_dir)
    
    # Iterate repos
    
    repo_data = {
        'mac-mouse-fix': {
            'path': './',
            'xcloc_dir': None, # This will hold the result of the loop iteration
        },
        'mac-mouse-fix-website': {
            'path': website_repo,
            'xcloc_dir': None,
        }
    }
    
    for i, (repo_name, repo_info) in enumerate(repo_data.items()):
        
        # Extract
        repo_path = repo_info['path']
        
        # Find xcodeproj path
        xcodeproj_subpath = mflocales.path_to_xcodeproj[repo_name]
        xcodeproj_path = os.path.join(repo_path, xcodeproj_subpath)
        
        # Get locales for this project
        development_locale, translation_locales = mflocales.find_xcode_project_locales(xcodeproj_path)
        repo_locales = [development_locale] + translation_locales
        
        # Log
        print(f"Extracted locales from .xcodeproject at {xcodeproj_path}: {repo_locales}\n")
        
        # Validate locales
        # We want all repos of the mmf project to have the same locales
        
        if i > 0:
                
            missing_locales = set(previous_repo_locales).difference(set(repo_locales))
            additional_locales = set(repo_locales).difference(set(previous_repo_locales))
            
            def _debug_names(locales):
                return list(map(lambda l: f'{ mflocales.language_tag_to_language_name(l) } ({l})', locales))
            assert len(missing_locales) == 0, f'There are missing locales in the xcode project {xcodeproj_path} compared to the locales in {previous_xcodeproj_path}:\nmissing_locales: {_debug_names(missing_locales)}\nAdd these locales to the former xcodeproj or remove them from latter xcodeproj to resolve this error.'
            assert len(additional_locales) == 0, f'There are additional locales in the xcode project {xcodeproj_path}, compared to the locales in {previous_xcodeproj_path}:\nadditional_locales: {_debug_names(additional_locales)}\nRemove these locales from the former xcodeproj or add them to latter xcodeproj to resolve this error.'
        
        previous_xcodeproj_path = xcodeproj_path
        previous_repo_locales = repo_locales
        
        # Log
        print(f"Loading all .xcstring files ...\n")
        
        # Load all .xcstrings files
        xcstring_objects = []
        glob_pattern = './' + os.path.normpath(f'{repo_path}/**/*.xcstrings') # Not sure normpath is necessary
        xcstring_filenames = glob.glob(glob_pattern, recursive=True)
        for f in xcstring_filenames:
            with open(f, 'r') as content:
                xcstring_objects.append(json.load(content))
        
        # Store stuff for localization_progress
        xcstring_objects_all_repos += xcstring_objects
        translation_locales_all_repos = translation_locales # Since we assert that the translation_locales are the same for all repos, this works
        
        # Log
        print(f".xcstring file paths: { json.dumps(xcstring_filenames, indent=2) }\n")
        
        # Create a folder to store .xcloc files to
        xcloc_dir = os.path.join(temp_dir, f'{repo_name}-xcloc-export')
        if os.path.isdir(xcloc_dir):
            shutil.rmtree(xcloc_dir) # Delete if theres already something there (I think this is impossible since we freshly create the temp_dir)
        os.mkdir(xcloc_dir)
        
        # Log
        print(f"Exporting .xcloc files in {repo_name} for each translations_locale (might take a while) ... \n")
        
        # Export .xcloc file for each locale
        locale_args = [ arg for l in translation_locales for arg in ['-exportLanguage', l, '-includeScreenshots']] # This python syntax is confusing. I feel like the `l in` and `arg in` sections should be swapped
        export_localizations_command = ['xcrun', 'xcodebuild', '-exportLocalizations', '-project', mflocales.path_to_xcodeproj[repo_name], '-localizationPath', f'{xcloc_dir}', *locale_args, '-verbose']
        mfutils.runclt(export_localizations_command, cwd=repo_path)
        
        # Log
        print(f"Exported .xcloc files using command: {export_localizations_command}\n")
        
        # Store result
        repo_data[repo_name]['xcloc_dir'] = xcloc_dir
    
    # Get combine localization_progress
    localization_progess_all_repos = mflocales.get_localization_progress(xcstring_objects_all_repos, translation_locales_all_repos)
    
    # Rename .xcloc files and put them in subfolders
    #   With one subfolder per locale
    
    xcloc_file_names = {
        'mac-mouse-fix': 'Mac Mouse Fix.xcloc',
        'mac-mouse-fix-website': 'Mac Mouse Fix Website.xcloc',
    }
    folder_name_format = "Mac Mouse Fix Translations ({})"
    
    locale_export_dirs = []
    for l in translation_locales:
        
        language_name = mflocales.language_tag_to_language_name(l)
        target_folder = os.path.join(temp_dir, folder_name_format.format(language_name))
        
        for repo_name, repo_info in repo_data.items():
            
            current_path = os.path.join(repo_info['xcloc_dir'], f'{l}.xcloc')
            
            target_path = os.path.join(target_folder, xcloc_file_names[repo_name])
            mfutils.runclt(['mkdir', '-p', target_folder]) # -p creates any intermediate parent folders
            mfutils.runclt(['mv', current_path, target_path])
            

        locale_export_dirs.append(target_folder)
    
    # Log
    print(f'Moved .xcloc files into folders: {locale_export_dirs}\n')
    
    # Zipping up folders containing .xcloc files 
    print(f"Zipping up .xcloc files ...\n")
    
    zip_file_format = "MacMouseFixTranslations.{}.zip" # GitHub Releases assets seemingly can't have spaces, that's why we're using this separate format
    
    zip_files = {}
    for l, l_dir in zip(translation_locales, locale_export_dirs):
        
        base_dir = temp_dir
        zippable_dir_path = l_dir
        zippable_dir_name = os.path.basename(os.path.normpath(zippable_dir_path))
        zip_file_name = zip_file_format.format(l)
        zip_file_path = os.path.join(base_dir, zip_file_name)
        
        if os.path.exists(zip_file_path):
            rm_result = mfutils.runclt(['rm', '-R', zip_file_path]) # We first remove any existing zip_file, because otherwise the `zip` CLT will combine the existing archive with the new data we're archiving which is weird. (If I understand the `zip` man correctly`)
            print(f'Zip file of same name already existed. Calling rm on the zip_file returned: { mfutils.clt_result_description(rm_result) }')
            
        zip_result = mfutils.runclt(['zip', '-r', zip_file_name, zippable_dir_name], cwd=base_dir) # We need to set the cwd (current working directory) like this, if we use abslute path to the zip_file and xcloc file, then the `zip` clt will recreate the whole path from our system root inside the zip archive. Not sure why.
        # print(f'zip clt returned: { zip_result }')
        
        with open(zip_file_path, 'rb') as zip_file:
            # Load the zip data
            zip_file_content = zip_file.read()
            # Store the data in the GitHub API format
            zip_files[l] = {
                'name': zip_file_name,
                'content': zip_file_content,
            }
            
    print(f"Finished zipping up .xcloc files at {temp_dir}\n")
    
    print(f"Uploading to GitHub ...\n")
    
    # Find GitHub Release
    response = mfgithub.github_releases_get_release_with_tag(args.api_key, 'noah-nuebling/mac-mouse-fix-localization-file-hosting', 'arbitrary-tag') # arbitrary-tag is the tag of the release we want to use, so it is not, in fact, arbitrary
    release = response.json()
    print(f"Found release { release['name'] }, received response: { mfgithub.response_description(response) }")
    
    # Delete all Assets 
    #   from GitHub Release
    for asset in release['assets']:
        response = mfgithub.github_releases_delete_asset(args.api_key, 'noah-nuebling/mac-mouse-fix-localization-file-hosting', asset['id'])
        print(f"Deleted asset { asset['name'] }, received response: { mfgithub.response_description(response) }")
    
    # Upload new Assets
    #   to GitHub Release
    
    download_urls = {}
    for zip_file_locale, value in zip_files.items():
        
        zip_file_name = value['name']
        zip_file_content = value['content']
        
        response = mfgithub.github_releases_upload_asset(args.api_key, 'noah-nuebling/mac-mouse-fix-localization-file-hosting', release['id'], zip_file_name, zip_file_content)        
        download_urls[zip_file_locale] = response.json()['browser_download_url']
        
        print(f"Uploaded asset { zip_file_name }, received response: { mfgithub.response_description(response) }")
        
    print(f"Finshed Uploading to GitHub. Download urls: { json.dumps(download_urls, indent=2) }")
    
    # Create markdown
    new_discussion_body = """\
<!-- AUTOGENERATED - DO NOT EDIT --> 
    
> [!WARNING]
> **This is a work in progress - do not follow the instructions in this document**
    
Mac Mouse Fix can now be translated into different languages! 🌍 

And you can help! 🧠

## How to Contribute

To contribute translations to Mac Mouse Fix, follow these steps:

1. **Download Translation Files**
    <details> 
      <summary><ins>Download</ins> the translation files for the language you want to translate Mac Mouse Fix into.</summary>
    <br>

{download_table}

    *If your language is missing from this list, please let me know in a comment below.*
    
    </details>
    
    <!--
    
    #### Further Infooo
    
    The download will contain two files: "Mac Mouse Fix.xcloc" and "Mac Mouse Fix Website.xcloc". Edit these files to translate Mac Mouse Fix.
    
    -->
    
2. **Download Xcode**
    
    [Download](https://apps.apple.com/de/app/xcode/id497799835?l=en-GB&mt=12) Xcode to be able to edit the translation files.
    <!--
    > [!NOTE] 
    > **Do I need to know programming?**
    > No. Xcode is Apples Software for professional Software Development. But don't worry, it has a nice user interface for editing translation files, and you don't have to know anything about programming or software development.
    --> 
    
3. **Edit the translation files files using Xcode**
    
    The Translation Files you downloaded have the file extension `.xcloc`. 
    
    Open these files in Xcode and then fill in your translations until the 'State' of every Translation shows a green checkmark.
    
    <br>
    
    <img width="759" alt="Screenshot 2024-06-27 at 10 38 27" src="https://github.com/noah-nuebling/mac-mouse-fix/assets/40808343/fb1067e9-18f4-4579-b147-cfea7f38caeb">
    
    <br><br>
    
    <details> 
      <summary><ins>Click here</ins> for a more <b>detailed explanation</b> about how to edit your .xcloc files in Xcode.</summary>
    
    1. **Open your Translation Files**
    
        After downloading Xcode, double click one of the .xcloc files you downloaded to begin editing it.
    
        <img width="607" alt="Screenshot 2024-06-27 at 09 24 39" src="https://github.com/noah-nuebling/mac-mouse-fix/assets/40808343/a70addcf-466f-4a92-8096-eee717ecc9fe">
    
    2. **Navigate the UI**
    
        After opeing your .xcloc file, browse different sections in the **Navigator** on the left, then translate the text in the **Editor** on the right.
    
        <img width="1283" alt="Screenshot 2024-06-27 at 09 25 44" src="https://github.com/noah-nuebling/mac-mouse-fix/assets/40808343/62eb0db2-02a0-46dd-bc59-37ad892915ee">
    
    3. **Find translations that need work**
    
        Click the 'State' column on the very right to sort the translatable text by its 'State'. Text with a Green Checkmark as it's state is probably ok, Text with other state may need to be reviewd or filled in.
    
        <img width="1341" alt="Screenshot 2024-06-27 at 09 30 10" src="https://github.com/noah-nuebling/mac-mouse-fix/assets/40808343/daea7f0d-d823-4c75-9f06-5a81c56f836e">
    
    4. **Edit Translations**
        
        Click a cell in the middle column to edit the translation.
    
        After you edit a translation, the 'State' will turn into a green checkmark, signalling that that you have reviewed and approved the translation.
        
        <img width="1103" alt="Screenshot 2024-06-27 at 10 47 04" src="https://github.com/noah-nuebling/mac-mouse-fix/assets/40808343/56b1f109-6319-4ba8-991d-8fced7b35f9b">
    
    
    </details>
    
4. **Submit your translations!**
    
    Once all your translations have a green checkmark, you can send the Translation files back to me and I will add them to Mac Mouse Fix!
    
    To send your Translation Files:
    - **Option 1**: Add a comment below this post. When creating the comment, drag-and-drop your translation files into the comment text field to send them along with your comment.
    - **Option 2**: Send me an email and add the translation files as an attachment.

## Credits

If your translations are accepted into the project you will receive a mention in the next Update Notes and your name will be added as a Localizer in the Acknowledgments!

<!--
(if your contribution was more than 10 strings or sth?)    
-->

## Conclusion

And that's it. If you have any questions, please write a comment below.

Thank you so much for your help in bringing Mac Mouse Fix to people around the world!


"""

    #
    # More minimalist
    # 

    new_discussion_body = new_discussion_body = """\
    
<!-- AUTOGENERATED - DO NOT EDIT --> 
    
> [!WARNING]
> **This is a work in progress - do not follow the instructions in this document**
    
Mac Mouse Fix can now be translated into different languages! 🌍 

And you can help! 🧠

## How to Contribute

To contribute translations to Mac Mouse Fix, follow these steps:

### 1. **Download Translation Files**
<details> 
    <summary><ins>Download</ins> the translation files for the language you want to translate Mac Mouse Fix into.</summary>
<br>

{download_table}

*If your language is missing from this list, please let me know in a comment below.*

</details>

<!--

#### Further Infooo

The download will contain two files: "Mac Mouse Fix.xcloc" and "Mac Mouse Fix Website.xcloc". Edit these files to translate Mac Mouse Fix.

-->

### 2. **Download Xcode**

[Download](https://apps.apple.com/de/app/xcode/id497799835?l=en-GB&mt=12) Xcode to be able to edit the translation files.
<!--
> [!NOTE] 
> **Do I need to know programming?**
> No. Xcode is Apples Software for professional Software Development. But don't worry, it has a nice user interface for editing translation files, and you don't have to know anything about programming or software development.
--> 

### 3. **Edit the translation files files using Xcode**

The Translation Files you downloaded have the file extension `.xcloc`. 

Open these files in Xcode and then fill in your translations until the 'State' of every Translation shows a green checkmark.

<br>

<img width="759" alt="Screenshot 2024-06-27 at 10 38 27" src="https://github.com/noah-nuebling/mac-mouse-fix/assets/40808343/fb1067e9-18f4-4579-b147-cfea7f38caeb">

<br><br>

<details> 
    <summary><ins>Click here</ins> for a more <b>detailed explanation</b> about how to edit your .xcloc files in Xcode.</summary>

1. **Open your Translation Files**

    After downloading Xcode, double click one of the .xcloc files you downloaded to begin editing it.

    <img width="607" alt="Screenshot 2024-06-27 at 09 24 39" src="https://github.com/noah-nuebling/mac-mouse-fix/assets/40808343/a70addcf-466f-4a92-8096-eee717ecc9fe">

2. **Navigate the UI**

    After opeing your .xcloc file, browse different sections in the **Navigator** on the left, then translate the text in the **Editor** on the right.

    <img width="1283" alt="Screenshot 2024-06-27 at 09 25 44" src="https://github.com/noah-nuebling/mac-mouse-fix/assets/40808343/62eb0db2-02a0-46dd-bc59-37ad892915ee">

3. **Find translations that need work**

    Click the 'State' column on the very right to sort the translatable text by its 'State'. Text with a Green Checkmark as it's state is probably ok, Text with other state may need to be reviewd or filled in.

    <img width="1341" alt="Screenshot 2024-06-27 at 09 30 10" src="https://github.com/noah-nuebling/mac-mouse-fix/assets/40808343/daea7f0d-d823-4c75-9f06-5a81c56f836e">

4. **Edit Translations**
    
    Click a cell in the middle column to edit the translation.

    After you edit a translation, the 'State' will turn into a green checkmark, signalling that the translation has been reviewed and approved.
    
    <img width="1103" alt="Screenshot 2024-06-27 at 10 47 04" src="https://github.com/noah-nuebling/mac-mouse-fix/assets/40808343/56b1f109-6319-4ba8-991d-8fced7b35f9b">


</details>

### 4. **Submit your translations!**

Once all your translations have a green checkmark, you can send the Translation files back to me and I will add them to Mac Mouse Fix!

To send your Translation Files:
- **Option 1**: Add a comment below this post. When editing the comment, drag-and-drop your translation files into the comment text field to send them along with your comment.
- **Option 2**: Send me an email and add the translation files as an attachment.

## Credits

If your translations are accepted into the project you will receive a mention in the next Update Notes and your name will be added as a Localizer in the Acknowledgments!

<!--
(if your contribution was more than 10 strings or sth?)    
-->

## Conclusion

And that's it. If you have any questions, please write a comment below.

Thank you so much for your help in bringing Mac Mouse Fix to people around the world!


"""
    
    # Fill in data into markdown table
    
    download_table = ""
    
    download_table += """\
| Language | Translation Files | Completeness |
|:--- |:---:| ---:|
"""

    for locale in sorted(translation_locales, key=lambda l: mflocales.language_tag_to_language_name(l)): # Sort the locales by language name (Alphabetically)
        
        progress = localization_progess_all_repos[locale]
        progress_percentage = int(100 * progress['percentage'])
        download_name = 'Download'
        download_url = download_urls[locale]
        
        emoji_flag = mflocales.language_tag_to_flag_emoji(locale)
        language_name = mflocales.language_tag_to_language_name(locale)
        
        entry = f"""\
| {emoji_flag} {language_name} ({locale}) | [{download_name}]({download_url}) | ![Static Badge](https://img.shields.io/badge/{progress_percentage}%25-Translated-gray?style=flat&labelColor={'%23aaaaaa' if progress_percentage < 100 else 'brightgreen'}) |
"""
        download_table += entry
    
    new_discussion_body = new_discussion_body.format(download_table=download_table)
    
    # Escape markdown
    new_discussion_body = mfgithub.escape_for_upload(new_discussion_body)


    
    if no_api_key:
        
        print(f"No API key provided, can't upload result to GitHub")
    
    else:
    
        # Find discussion #1022
        find_discussion_result = mfgithub.github_graphql_request(args.api_key, """      
                                                                                           
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
        mutate_discussion_result = mfgithub.github_graphql_request(args.api_key, f"""
                                  
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
