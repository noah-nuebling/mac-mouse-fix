# pip imports
import requests

# stdlib imports
import json

# 
# GitHub integration
#

def response_description(response: requests.Response) -> str:
    
    # Notes:
    # - We return the status, the headers, and the body of the response
    # - For the body we try to parse it as json. If that doesn't work we return plain text instead.
    #   - `text`, `content`, and `json` are all different representations for the main body of the response as far as I understand. According to ChatGPT, if only part of the body is parsable as json, then .json() would not be None, but yet, `text` or `content` could contain extra info. In that case we're missing this extra info. I don't think this will matter.
    
    status = response.status_code
    headers = response.headers
    body_text = response.text
    body_content = response.content
    body_json = None
    try:
        body_json = response.json()
    except:
        body_json = None
    
    body = body_json if body_json != None else body_text
    
    return_data = {
        'status': status,
        'headers': dict(headers), # Need to convert this since it's a "CaseSensitiveDict"
        'body': body,
    }
    
    return json.dumps(return_data, indent=2)

def github_rest_api_headers(api_key, for_uploading_binary=False): # Found these values in the github docs
    
    result = {
        'Accept': 'application/vnd.github+json',
        'Authorization': f'Bearer {api_key}',
        'X-GitHub-Api-Version': '2022-11-28',
    }
    if for_uploading_binary:
        result = { 
            **result, 
            **{ 'Content-Type': 'application/octet-stream' }
        }
        
    return result

def github_releases_get_release_with_tag(api_key, owner_and_repo, tag):
    response = requests.get(f'https://api.github.com/repos/{owner_and_repo}/releases/tags/{tag}', headers=github_rest_api_headers(api_key))
    assert 200 <= response.status_code < 300, f'GitHub Release retrieval failed. Code: { response.status_code }, JSON: { response.json() }'
    return response

def github_releases_list_assets_for_release(api_key, owner_and_repo, release_id):
    # Notes
    # - We don't need to use this. The json that github_releases_get_release_with_tag() returns already contains a list of assets
    
    assert(False)
    
    response = requests.get(f'https://api.github.com/repos/{owner_and_repo}/releases/{release_id}/assets', headers=github_rest_api_headers(api_key))
    return response

def github_releases_delete_asset(api_key, owner_and_repo, asset_id):
    response = requests.delete(f'https://api.github.com/repos/{owner_and_repo}/releases/assets/{asset_id}', headers=github_rest_api_headers(api_key))
    assert 200 <= response.status_code < 300, f'GitHub Release asset deletion failed. Code: { response.status_code }, JSON: { response.json() }'
    return response

def github_releases_upload_asset(api_key, owner_and_repo, release_id, asset_name, asset_binary_data):
    headers = github_rest_api_headers(api_key, for_uploading_binary=True)
    response = requests.post(f'https://uploads.github.com/repos/{owner_and_repo}/releases/{release_id}/assets?name={asset_name}', headers=headers, data=asset_binary_data)
    assert 200 <= response.status_code < 300, f'GitHub Release asset upload failed. Code: { response.status_code }, JSON: { response.json() }'
    return response

def github_gists_request(api_key, data):
    
    # Notes:
    # - We intended to upload our .xcloc files to gists, but that seems impossible. Trying to use gh releases for filehosting instead
    
    pass

def github_graphql_request(api_key, query):

    # Notes:
    # - Use GitHub GraphQL Explorer to create queries (https://docs.github.com/en/graphql/overview/explorer)

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