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
    

    
#
# Define main
#
    
def main():
    
    # Get locales for this project
    print(f"Extract locales from .xcodeproject ...")
    
    pbxproject_json = json.loads(shared.runCLT(f"plutil -convert json -r -o - Mouse\ Fix.xcodeproj/project.pbxproj").stdout) # -r puts linebreaks into the json which is unnecessary here.
    development_locale = None
    locales = None
    for obj in pbxproject_json['objects'].values():
        if obj['isa'] == 'PBXProject':
            locales = obj['knownRegions']
            development_locale = obj['developmentRegion']
            break
    
    assert(development_locale != None and locales != None and len(locales) >= 1)
    
    # Filter locales
    print(f"Filtering out Base and development locales ...")
    locales = [l for l in locales if l != development_locale and l != 'Base']
    print(f"Filtered locales: { locales }")
    
    # Load all .xcstrings files
    print(f"Loading all xcstring files")
    xcstring_objects = []
    xcstring_filenames = glob.glob("**/*.xcstrings", recursive=True)
    for f in xcstring_filenames:
        with open(f, 'r') as content:
            xcstring_objects.append(json.load(content))
    print(f".xcstring file paths: { json.dumps(xcstring_filenames, indent=2) }")
    
    
    # Create an overview of how many times each translation state appears for each language
    print(f"Determine localization state overview ...")
    localization_state_overview = defaultdict(lambda: defaultdict(lambda: 0))
    for xcstring_object in xcstring_objects:
        for key, string_dict in xcstring_object['strings'].items():
            
            for locale in locales:
                
                s = string_dict.get('localizations', {}).get(locale, {}).get('stringUnit', {}).get('state', 'mmf_indeterminate')
                assert(s == 'new' or s == 'needs_review' or s == 'translated' or s == 'stale' or s == 'mmf_indeterminate')        
                
                localization_state_overview[locale][s] += 1
    
    localization_state_overview = json.loads(json.dumps(localization_state_overview)) # Convert nested defaultdict to normal dict - which prints in a pretty way
    
    print(f"Localization state overview: ")
    pprint(localization_state_overview)
    
    # Get translation progress for each language
    #   Notes: 
    #   - Based on my testing, this seems to be accurate except that it didn't catch the missing translations for the Info.plist file. That's because the info.plist file doesn't have an .xcstrings file at the moment but we can add one.
    print(f"Determine localization progress ...")
    localization_progress = {}
    for locale, states in localization_state_overview.items():
        translated_count = states.get('translated', 0)
        to_translate_count = states.get('translated', 0) + states.get('needs_review', 0) + states.get('new', 0) + states.get('mmf_indeterminate', 0) # Note how we're ignoring stale strings here. (Stale means that the kv-pair is superfluous and doesn't occur in the base file/source code file afaik, therefore it's not part of 'to_translate' set)
        localization_progress[locale] = {'translated': translated_count, 'to_translate': to_translate_count, 'percentage': translated_count/to_translate_count}
    print(f"Localization progress: {localization_progress}")    
    
    # Get a temp dir to store exported .xcloc files to
    temp_dir = tempfile.gettempdir()
    xcloc_dir = os.path.join(temp_dir, 'mmf-xcloc-export')
    shutil.rmtree(xcloc_dir)
    os.mkdir(xcloc_dir)
    
    # Export .xcloc file for each locale
    print(f"Exporting .xcloc files for locales ...")
    locale_args = ' '.join([ '-exportLanguage ' + l for l in locales ])
    shared.runCLT(f"xcodebuild -exportLocalizations -localizationPath { xcloc_dir } { locale_args }")
    print(f"Exported .xcloc files to {xcloc_dir}")
    
    
#
# Call main
#

if __name__ == "__main__":
    main()