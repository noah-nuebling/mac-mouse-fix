
#
# Imports
#

import argparse
import mfutils
import os

#
# Constants
#

scripts_repo_ssh = 'git@github.com:noah-nuebling/mac-mouse-fix-scripts.git'
scripts_repo_branch = 'main'

#
# Main
#

def main():
    
    parser = argparse.ArgumentParser()
    parser.add_argument('action', help='`push` or `pull` the subtree')
    parser.add_argument('--scripts_dir', help='Passed automatically by run.py.')
    args = parser.parse_args()
    action = args.action
    scripts_dir = args.scripts_dir
    subtree_prefix = os.path.basename(os.path.normpath(scripts_dir))
    
    if action == 'push':
        mfutils.runclt(f'git subtree push --prefix {subtree_prefix} {scripts_repo_ssh} {scripts_repo_branch}')
    elif action == 'pull':
        mfutils.runclt(f'git subtree pull --prefix {subtree_prefix} {scripts_repo_ssh} {scripts_repo_branch} --squash')
    else:
        assert False, f'Unknown action "{action}". Use "push" or "pull"'
    

#
# Call main
#

if __name__ == '__main__':
    main()