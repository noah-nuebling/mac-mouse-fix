
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

xcode_project = 'Mouse\ Fix.xcodeproj/'
custom_xcstrings_files = ['Markdown.xcstrings'] # These .xcstrings files are created and managed by MMF instead of Xcode, so we need to treat them differently

#
# Define main
#
    
def main():
    
    # Inital free line to make stuff look nicer
    print("")
    
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
    
    # Get locales for this project
    print(f"Extracting locales from .xcodeproject ...")
    
    development_locale, translation_locales = mflocales.find_locales('Mouse\ Fix.xcodeproj')
    
    # Load all .xcstrings files
    print(f"Loading all .xcstring files ...\n")
    xcstring_objects = []
    xcstring_filenames = glob.glob("**/*.xcstrings", recursive=True)
    for f in xcstring_filenames:
        with open(f, 'r') as content:
            xcstring_objects.append(json.load(content))
    print(f".xcstring file paths: { json.dumps(xcstring_filenames, indent=2) }\n")
    
    # Get localization progress
    localization_progress = mflocales.get_localization_progress(xcstring_objects, translation_locales)
    
    # Add Markdown.xcstrings to 'Mac Mouse Fix' build target
    #   - Otherwise it won't be exported
    mflocales.make_custom_xcstrings_visible_to_xcodebuild(xcode_project, custom_xcstrings_files)
    
    # Get a temp dir to store exported .xcloc files to
    temp_dir = tempfile.gettempdir()
    xcloc_dir = os.path.join(temp_dir, 'mmf-xcloc-export')
    shutil.rmtree(xcloc_dir)
    os.mkdir(xcloc_dir)
    
    # Export .xcloc file for each locale
    print(f"Exporting .xcloc files for locales (might take a while) ... \n")
    locale_args = ' '.join([ '-exportLanguage ' + l for l in translation_locales ])
    mfutils.runCLT(f'xcodebuild -exportLocalizations -localizationPath "{ xcloc_dir }" { locale_args }')
    print(f"Exported .xcloc files to {xcloc_dir}\n")
    
    # Rename .xcloc files and put them in subfolders
    
    folder_name_format = "Mac Mouse Fix Translations ({})"
    zip_file_format = "MacMouseFixTranslations.{}.zip" # GitHub Releases assets seemingly can't have spaces, that's why we're using this separate format
    
    for l in translation_locales:
        language_name = mflocales.language_tag_to_language_name(l)
        current_path = os.path.join(xcloc_dir, f'{l}.xcloc')
        target_folder = os.path.join(xcloc_dir, folder_name_format.format(language_name))
        target_path = os.path.join(target_folder, 'Mac Mouse Fix.xcloc')
        mfutils.runCLT(f'mkdir -p "{target_folder}"') # -p creates any intermediate parent folders
        mfutils.runCLT(f'mv "{current_path}" "{target_path}"')
    
    # Zipping up folders containing .xcloc files 
    print(f"Zipping up .xcloc files ...\n")
    zip_files = {}
    for l in translation_locales:
        
        language_name = mflocales.language_tag_to_language_name(l)
        folder_name = folder_name_format.format(language_name)
        target_folder = os.path.join(xcloc_dir, folder_name)
        zip_file_name = zip_file_format.format(l)
        zip_file_path = os.path.join(xcloc_dir, zip_file_name)
        
        if os.path.exists(zip_file_path):
            rm_result = mfutils.runCLT(f'rm -R "{zip_file_path}"') # We first remove any existing zip_file, because otherwise the `zip` CLT will combine the existing archive with the new data we're archiving which is weird. (If I understand the `zip` man correctly`)
            print(f'Zip file of same name already existed. Calling rm on the zip_file returned: { mfutils.clt_result_description(rm_result) }')
            
        zip_result = mfutils.runCLT(f'zip -r "{zip_file_name}" "{folder_name}"', cwd=xcloc_dir) # We need to set the cwd (current working directory) like this, if we use abslute path to the zip_file and xcloc file, then the `zip` clt will recreate the whole path from our system root inside the zip archive. Not sure why.
        print(f'zip clt returned: { mfutils.clt_result_description(zip_result) }')
        
        with open(zip_file_path, 'rb') as zip_file:
            # Load the zip data
            zip_file_content = zip_file.read()
            # Store the data in the GitHub API format
            zip_files[l] = {
                'name': zip_file_name,
                'content': zip_file_content,
            }
            
    print(f"Finished zipping up .xcloc files.\n")
    
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
        
        progress = localization_progress[locale]
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
