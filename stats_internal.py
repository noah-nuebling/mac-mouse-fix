# Imports

import sys
import datetime
import collections
import json
from pprint import pprint
from typing import OrderedDict
import urllib.request
import urllib.parse

import matplotlib.pyplot as plt
import numpy as np

releases_api_url = "https://api.github.com/repos/noah-nuebling/mac-mouse-fix/releases"
history_file_path = 'stats_history.json'

# Main

def main():

    if len(sys.argv) == 1: # Print current downloads
        releases = load_releases()
        releases = sorted_by_release(releases, 'published_at')
        total_downloads = 0
        for r in releases:
            short_version = r['name']
            downloads = r['assets'][0]['download_count']
            total_downloads += downloads
            print(f'{short_version}: {downloads}')
        print(f'\ntotal: {total_downloads}')

    elif len(sys.argv) >= 2:

        command_line_argument = sys.argv[1]

        if command_line_argument == 'record':
            # Load existing log

            history = load_history()
            releases = load_releases()

            current_time = datetime.datetime.utcnow()

            for r in releases:

                # Get short version
                short_version = r['name']

                # Get download count
                downloads = r['assets'][0]['download_count']

                # Append to log
                make_path(history, short_version, str(current_time))['download_count'] = downloads
                # log[short_version][current_time]['download_count'] = downloads

            # Print
            print(f'New datapoints recorded for {current_time}. View them with `./stats print`')

            # Write log to file
            with open(history_file_path, 'w') as outfile:
                outfile.write(json.dumps(history))
        elif command_line_argument == 'print':
            history = load_history()
            print_nested(sorted_by_release(history, 'name'))
        elif command_line_argument == 'plot':
            
            # Get version arg (needs to be of the format '2.0.0 Beta 5')
            
            history = load_history()    
            
            if len(sys.argv) == 2:
                sys.argv.append('total') # No s_arg is the same as s_arg == 'total'
            
            s_arg = sys.argv[2] # Get first sub arg
            
            if s_arg == 'all' or s_arg == 'total':
                versions = history.keys()                    
            elif s_arg == 'all-stable':
                versions = history.keys()
                versions = filter(lambda version_string: ' ' not in version_string, versions) # Filter out prereleases
            else:
                versions = sys.argv[2:]
            
            plot_data = []
            
            for version in versions:
                
                vh = history[version]
                
                x = []
                y = []
                
                for date in vh:
                    downloads = int(vh[date]['download_count']) # Parse downloads string into int
                    date = datetime.datetime.fromisoformat(date) # Parse date string into date object
                    
                    x.append(date)
                    y.append(downloads)


                plot_data.append({
                    'version': version,
                    'x': x,
                    'y': y,
                })
            
            if s_arg == 'total':
                # Source: https://stackoverflow.com/a/55290542/10601702

                # Get x values for each version
                x_each = list(map(lambda a: a['x'], plot_data)) # List of list of dates for each version
                
                # Convert dates to timestamps so that interpolation works
                x_each = [[d.timestamp() for d in v] for v in x_each]
                
                # Get sorted list of all x values for all versions
                x_combined = np.unique(np.concatenate(x_each))
                
                # Get y values for each version
                y_each = list(map(lambda a: a['y'], plot_data))
                
                # interpolate y values on the combined x values
                itp = []
                for idx, (x, y) in enumerate(zip(x_each, y_each)):
                    r = np.interp(x_combined, x, y, left=0, right=0)
                    itp.append(r)

                y_summed = sum(itp)
                
                x_combined = [datetime.datetime.utcfromtimestamp(d) for d in x_combined]

                plt.plot(x_combined, y_summed, label="Total downloads", linestyle='-', marker='.')
                
                plt.gcf().autofmt_xdate()
                plt.legend(loc='upper left')
                plt.show()
                
            else:
                for d in plot_data:
                    plt.plot(d['x'], d['y'], label=d['version'], linestyle='-', marker='.')
                    
                plt.legend(loc='upper left')
                plt.gcf().autofmt_xdate()
                plt.show()
            
        else:
            raise Exception('Unknown command line argument.')
    else:
        raise Exception('Too many command line arguments.')

def load_releases():
    request = urllib.request.urlopen(releases_api_url)
    releases = json.load(request)
    return releases

def load_history():
    log = {}
    try:
        with open(history_file_path, 'r') as f:
            log = json.load(f)
    except Exception as e:
        print(f'Exception while opening history file: {e}')
    return log

# Source: https://stackoverflow.com/questions/60808884/python-to-create-dict-keys-path-similarly-to-mkdir-p
def make_path(my_dict: dict, *paths: str) -> dict:
    while paths:
        key, *paths = paths
        my_dict = my_dict.setdefault(key, {})
    return my_dict

def print_nested(val, nesting = -4): 
	if isinstance(val, dict): 
		print('') 
		nesting += 4
		for k in val: 
			print(nesting * ' ', end='') 
			print(k, end=': ') 
			print_nested(val[k],nesting) 
	else: 
		print(val) 

def sorted_by_release(arg, key):
    if isinstance(arg, list):
        return sorted(arg, key = lambda i: i[key])
    elif isinstance(arg, dict):
        return collections.OrderedDict(sorted(arg.items()))
    else:
        raise Exception('Unexpected argument type')

main()
