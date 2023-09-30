# Imports

import sys
import datetime
import collections
import json
from pprint import pprint
from typing import OrderedDict
import urllib.request
import urllib.parse
import matplotlib
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
        print(f'\nUTC time: {datetime.datetime.utcnow()}\n')

    elif len(sys.argv) >= 2:
        
        command_line_argument = sys.argv[1]
        
        if command_line_argument == '--help':
            print(
                """
`stats` command line tool

### Subcommands
    
**`record`**
    Record current downloads. Store results in history file.
**`print`**
    Print all recorded data to the console.
**`plot`**
    Visualize the recorded data in a graph.
    _Subcommands_:
    `latest`
        See downloads for the latest stable release
    `total`
        Total number of downloads across all versions.
    `<list of versions>`
        Provide a list of version names you want to compare.
        The version names are the titles of the corresponding GitHub releases. (Would probably be better to use the git tag instead)
        Example of usage:
            `./stats plot "2.0.0" "2.0.0 Beta 13"`
    `all`
        Separate graph for each release.
    `all-stable`
        Separate graph for each release. Omit beta versions.
                """)    
            exit()
        elif command_line_argument == 'record':
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
            print(f'New datapoints recorded for utc time: {current_time}. View them with `./stats print` or `./stats plot`')

            # Write log to file
            with open(history_file_path, 'w') as outfile:
                outfile.write(json.dumps(history, indent=2)) # Print with indent so eveything is on seperate lines. If there's only one line, git doesn't register changes properly.
                
        elif command_line_argument == 'print':
            history = load_history()
            print_nested(sorted_by_release(history, 'name'))
        elif command_line_argument == 'plot':
            
            # Get version arg (needs to be of the format '2.0.0 Beta 5')
            
            history = load_history()    
            
            if len(sys.argv) == 2: # No sub argument
                sys.argv.append('total')
            
            s_arg = sys.argv[2] # Get first sub arg
            
            versions = []
            if s_arg == 'all' or s_arg == 'total':
                versions = history.keys()                    
            elif s_arg == 'all-stable':
                versions = history.keys()
                versions = filter(lambda version_string: ' ' not in version_string, versions) # Filter out prereleases
            elif s_arg == 'latest':
                versions.append(load_latest_release()['name'])
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
                
                # Sum up the download numbers of each version to get totals
                
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

                # Sum the y values up to get total downloads
                y_summed = sum(itp)
                
                # Convert timestamps to datetime
                x_combined_dates = [datetime.datetime.fromtimestamp(d) for d in x_combined] # Using utcfromtimestamp here actually gives us the wrong time. (Because it tries to convert the time again?) We need to use fromtimestamp() to get utc time.
                
                # Replace plot_data
                plot_data = [{
                    'version': 'All Versions',
                    'x': x_combined_dates,
                    'y': y_summed,
                }]
            
            if len(plot_data) == 1:
                
                # Source: https://stackoverflow.com/a/55290542/10601702
                
                # Setup graph for drawing 2 axes
                
                fig, ax1 = plt.subplots()
                ax2 = ax1.twinx()
                
                color = 'tab:blue'
                ax1.set_xlabel('Date')
                ax1.set_ylabel('Total downloads', color=color)
                # plt.plot(x,y, linestyle='-', marker='.', color=color) # Need to draw on plot not axis to get mouse hover values to work
                ax1.tick_params(axis='y', labelcolor=color)
                ax1.axhline(y=0, color='black', linestyle='--')
                
                # Downloads per day
                
                first_date = plot_data[0]['x'][0]
                last_date = plot_data[0]['x'][-1]
                
                delta = (last_date - first_date)
                
                days = []
                interval = 60*60*24 # Should be seconds in a day, but can lower for testing
                
                for i in reversed(range(int(delta.total_seconds()//interval))):
                    days.append(last_date - datetime.timedelta(seconds=i*interval))
                days_timestamps = [d.timestamp() for d in days]
                
                day_values = np.interp(days_timestamps, [d.timestamp() for d in plot_data[0]['x']], plot_data[0]['y'], left=0, right=0)
                
                middle_dates = []
                for i in range(len(days)-1):
                    middle_dates.append(datetime.datetime.fromtimestamp((days[i].timestamp() + days[i+1].timestamp())/2))
                
                x_p = middle_dates
                y_p = np.diff(day_values)
                
                # Plot
                
                color2 = 'tab:red'
                ax2.set_ylabel('Downloads per day', color=color2)  # we already handled the x-label with ax1
                ax2.tick_params(axis='y', labelcolor=color2)
                ax2.axhline(y=0, color='black', linestyle='--')
                
                ax2.format_coord = make_format(ax2, ax1)
                
                ax1.plot(plot_data[0]['x'], plot_data[0]['y'], linestyle='-', marker='.', color=color)
                ax2.plot(x_p, y_p, linestyle='-', marker='.', color=color2)
                
                plt.gcf().autofmt_xdate()
                fig.tight_layout()  # otherwise the right y-label is slightly clipped
                
                # Draw point coordinates (doesn't work)
                
                # plt.rcParams["figure.autolayout"] = True         
                # for x_i, y_i in zip(x, y):
                    
                #     plt.text(x_i, y_i, f'({x_i}, {y_i})')
                
                plt.legend(loc='best')
                plt.show()
                
            else: # if len(plot_data) > 1
                
                for d in plot_data:
                    
                    x = d['x']
                    y = d['y']
                    version = d['version']
                    
                    plt.plot(x, y, label=version, linestyle='-', marker='.')
                    
                plt.legend(loc='upper left')
                plt.gcf().autofmt_xdate()
                plt.show()
            
        else:
            raise Exception('Unknown command line argument.')
    else:
        raise Exception('Too many command line arguments.')

def load_releases():

    page = 1
    result = []
    
    while True:
        
        print(f'Loading releases page {page}...')
    
        # Using `?per_page=100` should decrease the number of requests and make things faster. But it doesn't work.
        #    See: https://stackoverflow.com/a/30656830/10601702
        request = urllib.request.urlopen(releases_api_url + '?page=' + str(page))
        releases = json.load(request)
        
        if releases == []:
            break
        result += releases
        page += 1
    
    return result

def load_latest_release():
    request = urllib.request.urlopen(releases_api_url + '/latest')
    latest = json.load(request)
    return latest

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

def cool_diff(array, n):
    # More stable than np.diff for our 'downloads per day' calculation
    # n how many values to look back / look forward
    # size(result) = size(array) - 2n
    
    if n == 0:
        return np.array(array)
    
    out = []
    
    for i, v in enumerate(array[n:-n]):
        diff = array[i+n] - array[i-n]
        out.append(diff)
    
    return np.array(out)
    
def make_format(current, other):
    # Src: https://stackoverflow.com/questions/21583965/matplotlib-cursor-value-with-two-axes
    
    # current and other are axes
    def format_coord(x, y):
        # x, y are data coordinates
        # convert to display coords
        display_coord = current.transData.transform((x,y))
        inv = other.transData.inverted()
        # convert back to data coords with respect to ax
        ax_coord = inv.transform(display_coord)
        coords = [ax_coord, (x, y)]
        # Get x axis string (date)
        datefmt = matplotlib.dates.DateFormatter("%d %b %Y")
        datestring = datefmt(x)
        
        return 'Total: {:.0f}          ({:<10})          Per day: {:.0f}'.format(ax_coord[1], datestring, y)
    return format_coord

main()
