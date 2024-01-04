#
# Imports
#
import sys
import argparse
import requests
# import json
import pycountry
import datetime
import babel.dates
import pathlib
import urllib.parse
import string
import os
import math

#
# Constants
#
# (We expect this script to be run from the root directory of the repo)

fallback_language_id = "en-US"

languages = {
    
    # Note for translators: To add a new entry for your language here, simply copy the German entry and replace all occurences of `de` with your language ID.
    #   Choose the same language ID that's used in the MMF Xcode project or find a language ID using this Apple documentation: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/LanguageandLocaleIDs/LanguageandLocaleIDs.html
    #   Language IDs are typically either just a language identifier, such as `de` for German, or to specify a regional dialect, you can use a language identifier plus a region identifier such as `de-CH` for Swiss German or `en-US` for American English.
    
    "en-US": {
        "language_name": "🇬🇧 English",                      # Language name will be displayed in the language picker
        "template_root": "Markdown/Templates/en-US/",
        "document_root": "",                                # The document root for english is the repo root.
    },
    "de": {
        "language_name": "🇩🇪 Deutsch",
        "template_root": "Markdown/Templates/de/",
        "document_root": "Markdown/LocalizedDocuments/de/", 
    },
}

documents = {
    
    "readme": {
        "template_subpath": "readme_template.md", # This subpath is appended to the "template_root" to make the full template path
        "document_subpath": "Readme.md", # This subpath is appended to the "document_root" to make the full document path
    },
    "acknowledgements": {
        "template_subpath": "acknowledgements_template.md",
        "document_subpath": "Acknowledgements.md",
    }
}

# !! Amend custom_field_labels if you change the UI strings on Gumroad !!

sales_count_rounder = 100 # Round sales counts to multiple of this number. This is to prevent the acknowledgements file from changing on every sale, which clogs up commit history a bit.

gumroad_custom_field_labels_name = ["Your Name – Will be displayed in the Acknowledgements if you purchase the 2. or 3. Option"]
gumroad_custom_field_labels_message = ["Your message (Will be displayed next to your name in the Acknowledgements if you purchase the 3. Option)", "Your message – Will be displayed next to your name in the Acknowledgements if you purchase the 3. Option"]
gumroad_custom_field_labels_dont_display = ["Don't publicly display me as a 'Generous Contributor' under 'Acknowledgements'"]

gumroad_product_id_euro = "FP8NisFw09uY8HWTvVMzvg=="
gumroad_product_id_dollar = "OBIdo8o1YTJm3lNvgpQJMQ=="
gumroad_product_ids = [gumroad_product_id_euro, gumroad_product_id_dollar] # 1st is is the € based product (Which we used in the earlier MMF 3 Betas, but which isn't used anymore), 2nd id is $ based product (mmfinappusd)

gumroad_api_base = "https://api.gumroad.com"
gumroad_sales_api = "/v2/sales"
gumroad_date_format = '%Y-%m-%dT%H:%M:%SZ' # T means nothing, Z means UTC+0 | The date strings that the gumroad sales api returns have this format

name_blacklist = ['mail', 'paypal', 'banking', 'beratung', 'macmousefix'] # TODO: Add Iam | When gumroad doesn't provide a name we use part of the email as the display name. We use the part of the email before @, unless it contains one of these substrings, in which case we use the part of the email after @ but with the `.com`, `.de` etc. removed
nbsp = '&nbsp;'  # Non-breaking space. &nbsp; doesn't seem to work on GitHub. Tried '\xa0', too. See https://github.com/github/cmark-gfm/issues/346

#
# Main
#
def main():
    
    # Parse args
    
    parser = argparse.ArgumentParser()
    parser.add_argument("--document")
    parser.add_argument("--api_key")
    parser.add_argument("--no_api", action='store_true')
    args = parser.parse_args()
    gumroad_api_key = args.api_key
    document_key = args.document
    no_api = args.no_api
    
    # Validate
    document_key_was_provided = isinstance(document_key, str) and document_key != ''
    if not document_key_was_provided:
        print("No document key provided. Provide one using the '--document' command line argument.")
        sys.exit(1)
    document_key_is_valid = document_key in documents.keys()
    if not document_key_is_valid:
        print(f"Unknown document key '{document_key}'. Valid document keys: {list(documents.keys())}")
        sys.exit(1)
    
    # Iterate language dicts

    document_dict = documents[document_key]
    
    for language_id, language_dict in languages.items():
        
        # Extract info from language_dict
        template_path = language_dict['template_root'] + document_dict['template_subpath']
        destination_path = language_dict['document_root'] + document_dict['document_subpath']
        
        template_exists = os.path.exists(template_path)
        
        if not template_exists:
            print(f"{document_dict} template for language {language_id} doesn't exist. Falling back to {fallback_language_id}")
            template_path = languages[fallback_language_id]['template_root'] + document_dict['template_subpath']
        
        # Load template
        template = ""
        with open(template_path) as f:
            template = f.read()
        
        # Log
        print('Inserting generated strings into template at {}...'.format(template_path))
        
        # Insert into template
        if document_key == "readme":
            template = insert_root_paths(template, document_dict, language_dict)
            template = insert_language_picker(template, document_dict, language_dict, languages)
        elif document_key == "acknowledgements":
            template = insert_root_paths(template, document_dict, language_dict) # This is not currently necessary here since we don't use the {root_path} placeholder in the acknowledgements templates
            template = insert_language_picker(template, document_dict, language_dict, languages)
            template = insert_acknowledgements(template, language_id, language_dict, gumroad_api_key, no_api)
        else:
            assert False # Should never happen because we check document_key for validity above.
        
        # Validate that template is completely filled out
        template_parse_result = list(string.Formatter().parse(template))
        template_fields = [tup[1] for tup in template_parse_result if tup[1] is not None]
        is_fully_formatted = len(template_fields) == 0
        if not is_fully_formatted:
            print(f"Something went wrong. Template at '{template_path}' still has format field(s) after inserting: {template_fields}")
            sys.exit(1)
        
        # Insert fallback notice
        if not template_exists:
            fallback_notice = f"""
<table align="center"><td align="center">
This document doesn't have a translation for <code>{language_dict['language_name']}</code> yet.<br>
If you want to help translate it, click <a align="center" href="https://github.com/noah-nuebling/mac-mouse-fix/discussions/731">here</a>.
</td></table>\n\n"""
            template = fallback_notice + template
        
        # Add comment to the top of the document which says that it is autogenerated
        template = "<!-- THIS FILE IS AUTOMATICALLY GENERATED - EDITS WILL BE OVERRIDDEN -->\n" + template
        
        # Create path
        destination_dir = os.path.dirname(destination_path)
        if len(destination_dir) > 0:
            os.makedirs(os.path.dirname(destination_path), exist_ok=True)
        
        # Write template
        with open(destination_path, mode="w") as f:
            f.write(template)
        
        # Log
        print('Wrote result to {}'.format(destination_path))
    
    
# 
# Template inserters 
#

sales_data_cache = None

def insert_acknowledgements(template, language_id, language_dict, gumroad_api_key, no_api):
    
    if no_api:
        template = template.replace('{very_generous}', 'NO_API').replace('{generous}', 'NO_API').replace('{sales_count}', 'NO_API')
        return template
    
    global sales_data_cache
    
    all_sales_count = None
    generous_sales = None
    very_generous_sales = None
    
    if sales_data_cache != None:
        
        #
        # Load from cache
        #
        
        all_sales_count = sales_data_cache['all_sales_count']
        generous_sales = sales_data_cache['generous_sales']
        very_generous_sales = sales_data_cache['very_generous_sales']
        
    else: 
        
        #
        # Load from scratch and store in cache
        #
    
        # Load all sales of the gumroad product
        
        sales = []
        
        for pid in gumroad_product_ids:
            
            page = 1
            api = gumroad_sales_api
            failed_attempts = 0

            while True:
                
                print('Fetching sales for product {} page {}...'.format(pid, page))
                
                response = requests.get(gumroad_api_base + api, 
                            headers={'Content-Type': 'application/x-www-form-urlencoded'},
                            params={'access_token': gumroad_api_key,
                                    'product_id': pid})
                
                if response.status_code == 200:
                    failed_attempts = 0
                else:
                    failed_attempts += 1
                    if response.status_code == 401:
                        print('(The request failed because it is unauthorized (status 401). This might be because you are not providing a correct Access Token using the `--api_key` command line argument. You can retrieve an Access Token in the GitHub Secrets or in the Gumroad Settings under Advanced. Exiting script.')
                        sys.exit(1)
                    elif failed_attempts <= 3:
                        print(f'The HTTP request failed with status {response.status_code}. Since the the gumroad servers sometimes randomly fail (normally with code 5xx), were trying again...')
                        continue
                    else:
                        print(f'The HTTP request failed with status {response.status_code}. Exiting script.')
                        sys.exit(1)
                
                response_dict = response.json()
                if response_dict['success'] != True:
                    print('Gumroad API returned failure. Exiting script.')
                    sys.exit(1)
                
                sales += response_dict['sales']
                
                if 'next_page_url' in response_dict:
                    api = response_dict['next_page_url']
                else:
                    break
                
                page += 1
        
        # Record all sales count
        
        all_sales_count = len(sales)
        
        # Log
        
        print('Sorting and filtering sales...')
        # print(json.dumps(sales, indent=2))
        
        # Filter people who don't want to be displayed
        
        print('')
        sales = list(filter(wants_display, sales))
        print('')
        
        # Sort sales by date
        sales.sort(key=(lambda sale: datetime.datetime.strptime(sale['created_at'], gumroad_date_format)), reverse=True)
        
        # Filter generous and very generous
        generous_sales = list(filter(is_generous, sales))
        very_generous_sales = list(filter(is_very_generous, sales))
    
        # Create cache and store in cache
        sales_data_cache = dict()
        sales_data_cache['all_sales_count'] = all_sales_count
        sales_data_cache['generous_sales'] = generous_sales
        sales_data_cache['very_generous_sales'] = very_generous_sales
    
    # Log
    print('Compiling generous contributor strings...')
    
    # Round sales count
    all_sales_count_rounded = round_to_multiple(all_sales_count, sales_count_rounder, math.floor)
    
    # Generate generous markdown
    
    generous_string = ''
    first_iteration = True
    for sale in generous_sales:
        
        if not first_iteration:
            generous_string += nbsp + ' ' # nbsp + '| '
        first_iteration = False
        
        generous_string += display_name(sale)

    # Generate very generous markdown
        
    very_generous_string = ''
    
    # Notes on babel_language_tag:
    #   'languageIDs' are used throughout the MMF project and are based on Apples Language IDs, who themselves implement a subset of the BCP 47 specification if I understand correctly. BCP 47 calls it 'language tags'. It seems the terms are interchangable.
    #   Babel works with so called 'language tags' which also follow the BCP 47 specification. So they seem to be the same thing as Apples language IDs. 
    #       However, for some reason babel replaces `-` (which is used in the BCP 47 spec that it refers to and by Apple) with `_`. Not sure why. Also, the babel references a really old, outdated version of the BCP 47 spec, but chatGPT said it should still be compatible with the Apple language IDs, 
    #       so we'll just auto-translate between apple language id and babel language tag by replacing `-` with `_`.
    
    #   References:
    #       - Apple language ID docs: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/LanguageandLocaleIDs/LanguageandLocaleIDs.html
    #       - Babel language tag docs: https://babel.pocoo.org/en/latest/api/core.html
    #       - BCP 47 specification that babel docs reference: https://datatracker.ietf.org/doc/html/rfc3066.html
    #       - BCP 47 latest specification at time of writing: https://datatracker.ietf.org/doc/html/rfc5646
    
    babel_language_tag = language_id.replace('-', '_') 
    
    last_month = None
    first_iteration = True
    
    for sale in very_generous_sales:
        date_string = sale['created_at']
        date = datetime.datetime.strptime(date_string, gumroad_date_format)
        if date == None:
            print('Couldnt extract date from string {}'.format(date_string))
            exit(1)
        
        if date.month != last_month:
            
            last_month = date.month
            
            if not first_iteration:
                very_generous_string += '\n\n'
            first_iteration = False
            
            very_generous_string += '**{}**\n'.format(babel.dates.format_datetime(datetime=date, format='LLLL yyyy', locale=babel_language_tag)) # See https://babel.pocoo.org/en/latest/dates.html and https://babel.pocoo.org/en/latest/api/dates.html#babel.dates.format_datetime.
        
        name = display_name(sale)
        message = user_message(sale, name)
        
        if len(message) > 0:
            very_generous_string += '\n- ' + name + f' - "{message}"'
        else:
            very_generous_string += '\n- ' + name
    
    # Log
    print('\nGenerous string:\n\n{}\n'.format(generous_string))
    print('Very Generous string:\n\n{}\n'.format(very_generous_string))
    
    print('Inserting into template:\n\n{}\n'.format(template))
    
    # Insert into template
    # str.format forces us to replace all the template placeholders at once, which we don't want, so we use str.replace
    
    # template = template.format(very_generous=very_generous_string, generous=generous_string, sales_count=all_sales_count)
    template = template.replace('{very_generous}', very_generous_string).replace('{generous}', generous_string).replace('{sales_count}', str(all_sales_count_rounded))
    
    # Return
    return template
    
def insert_language_picker(template, document_dict, language_dict, languages):
    
    # Extract data
        
    language_name = language_dict['language_name']
    language_dicts = languages.values()
    
    # Generate language list ui string
    
    ui_language_list = ''
    for i, language_dict2 in enumerate(language_dicts):
        
        is_last = i == len(language_dicts) - 1
        
        language_name2 = language_dict2['language_name']
        
        # Create relative path from the location of the `language_dict` document to the `language_dict2` document. This relative path works as a link. See https://github.blog/2013-01-31-relative-links-in-markup-files/
        path = language_dict['document_root'] + document_dict['document_subpath']
        path2 = language_dict2['document_root'] + document_dict['document_subpath']
        root_path = path_to_root(path)
        relative_path = root_path + path2
        link = urllib.parse.quote(relative_path) # This percent encodes spaces and others chars which is necessary
        
        ui_language_list += '  '
        
        if language_name == language_name2:
            ui_language_list += f'**{language_name2}**'
        else:
            ui_language_list += f'[{language_name2}]({link})'
        
        ui_language_list += '\\'
        if not is_last: 
            ui_language_list += '\n'
        
    # Log    
    print(f'\nLanguage picker language list generated for language "{language_name}":\n{ui_language_list}\n')
    # print('Inserting into template:\n\n{}\n'.format(template))
    
    # Insert generated strings into template
    # template = template.format(current_language=language_name, language_list=ui_language_list)
    template = template.replace('{current_language}', language_name).replace('{language_list}', ui_language_list)
    
    # Return
    return template

def insert_root_paths(template, document_dict, language_dict):
        
    # Notes: 
    # - Abstracting the "document_root" out makes it easy to link between markdown documents of the same language.
    #   For example, you can just `[link]({document_root}Acknowledgements.md)` to link to the acknowledgements file in the same language as the current document.
    # - Abstracting the "repo_root" makes it easy to link to any files in the repo, no matter where the compiled document ends up.
        
    # Extract info from language_dict
        
    path = language_dict['document_root'] + document_dict['document_subpath']
    repo_root = path_to_root(path)
    language_root = repo_root + language_dict['document_root']
    
    template = template.replace('{repo_root}', repo_root)
    template = template.replace('{language_root}', language_root)
    
    return template

# 
# Particle generators
#
 
def path_to_root(path):
    parent_count = len(pathlib.Path(path).parents)
    root_path = '../' * (parent_count-1)
    return root_path
 
def display_name(sale):
    
    name = ''

    # Special requests
    if sale['email'] == 'rawad.aboud@icloud.com': # Gumroad api says he's from IL-TA (Tel Aviv, Israel), but he's Palestinian. See [this mail](message:<8C5D64EE-447A-4A65-89A4-27F99115C986@icloud.com>)
        return '🇵🇸 Rawad Aboud'
    
    # Get user-provided name field
    #   We haven't tested this so far due to laziness
    
    name = gumroad_custom_field_content(sale, gumroad_custom_field_labels_name)
    if name == None: name = ''
    
    # Get full_name field
    if name == '':
        if 'full_name' in sale:
            name = sale['full_name']
    
    # Fallback to email-based heuristic
    if name == '':
        email = ''
        if 'email' in sale:
            email = sale['email']
        elif 'purchase_email' in sale:
            email = sale['purchase_email']
        else:
            sys.exit(1)
        
        n1, _, n2 = email.partition('@')
        
        use_n1 = True
        for non_name in name_blacklist:
            if non_name in n1:
                use_n1 = False
                break
        
        if use_n1:
            name = n1
        else:
            name = n2.partition('.')[0] # In a case like gm.ail.com, we want gm.ail, but this will just return gm. But should be good enough.

    # Replace weird separators with spaces
    for char in '._-–—+':
        name = name.replace(char, ' ')

    # Correct case
    #   The full_name field is sometimes in all caps and the email based heuristic returns all lower-case
    name = name.title()
    
    # Prepend flag
    flag = emoji_flag(sale)
    if flag != '':
        name = flag + ' ' + name
    
    # Replace all spaces with non-breaking spaces
    name = name.replace(' ', nbsp)
    
    return name
 
def emoji_flag(sale):
    
    country_code = sale.get('country_iso2', '')
    if country_code == '': # Does this ever happend?
        country_code = pycountry.countries.get(name=sale.get('country', '')).alpha_2
    
    if country_code == '':
        return ''
    
    result = ''
    for c in country_code.upper():
        result += chr(ord(c) + 127397)
    return result
 
def is_generous(sale):
    
    sale_pid = sale['product_id']
    
    if sale_pid == gumroad_product_id_euro:
        if sale['variants_and_quantity'] == '(2. Option)': 
            return True
        if sale['formatted_display_price'] == '€5': # Commenting this out doesn't change the results. Not sure why we wrote this - maybe the "variants_and_quantity" value used to be different from (2. Option) for a period?
            return True
    elif sale_pid == gumroad_product_id_dollar:
        if sale['variants_and_quantity'] == '(2. Option)':
            return True
    else:
        assert False
    
    return False
 
def is_very_generous(sale):
    
    sale_pid = sale['product_id']
    
    if sale_pid == gumroad_product_id_euro:
        if sale['variants_and_quantity'] == '(3. Option)':
            return True
        if sale['formatted_display_price'] == '€10': # Commenting this out doesn't change the results
            return True
    elif sale_pid == gumroad_product_id_dollar:
        if sale['variants_and_quantity'] == '(3. Option)':
            return True
    else:
        assert False
        
    return False
        
def wants_display(sale):
    
    dont_display = gumroad_custom_field_content(sale, gumroad_custom_field_labels_dont_display)
    if dont_display == None: dont_display = False
    
    result = not dont_display
    
    if result == False:
        print("{} payed {} and does not want to be displayed".format(display_name(sale), sale['formatted_display_price']))
    
    return result

def user_message(sale, name):
    
    # Get raw message from sale data
    message = gumroad_custom_field_content(sale, gumroad_custom_field_labels_message)
    if message == None: message = ''

    # Remove leading / trailing whitespace
    message = message.strip()
    
    # Debug
    if len(message) > 0:
        print("{} payed {} and left message: {}".format(name, sale['formatted_display_price'], message))
    
    # Remove message if it's in the name of the purchaser (Because we assume they did that accidentally)
    if len(message) > 0 and (message.lower() in name.replace(nbsp, ' ').lower()):
        print("{}'s message is contained in their name, so we're filtering it out".format(name))
        message = ''
    
    # Return
    return message

def gumroad_custom_field_content(sale, custom_field_labels):
    
    content = None
    if sale['has_custom_fields']:
        for label in custom_field_labels:
            content = sale['custom_fields'].get(label, None)
            if content != None:
                break

    return content

def round_to_multiple(n, multiple, rounding_fn=round):
    return rounding_fn(n / multiple) * multiple

#
# Call main
#
if __name__ == "__main__":
    main()
