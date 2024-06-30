#
# Imports
#
# (Only import stdlib stuff -> we want to run this without installing requirements)
# (Also don't import Shared stuff I think (?) since we want this to be independent of other stuff (not sure this requirement makes sense))

import os
import sys
import glob
import subprocess
import re
import json

#
# Constants
#

venv_path = "env"
dotenv_path = ".env"

# Command map

custom_command_compile_markdown = "compile-markdown"

subcommand_map = {
    "upload-strings": "Scripts/UploadXCStrings",
    custom_command_compile_markdown: "", # Custom logic which can't be described by a single path
    
    "sync-strings-internal": "Scripts/SyncXCStrings",
    "markdown-generator-internal": "Scripts/MarkdownGenerator",
    
    "mmf-website-compile-strings": "Scripts/MMFWebsiteCompileStrings",
}

help_string = """
Use ./run like this:

    ./run <subcommand> <args>

Known subcommands:

    {}

Provided subcommand:

    {}

"""

def print_help_and_exit(subcommand, exit_code=1):
    print(help_string.format(' | '.join(subcommand_map.keys()), subcommand))
    exit(exit_code)


#
# Documentation
#

"""

This is a convenience script. It invokes the other python scripts - 
    - after creating a venv, then installing the requirements.txt, and then loading environment variables from the ./.env file.

    We also have a bash script `./run` at the project root which simply dispatches to this script right here to make things EVEN MORE CONVENIENT

    So in effect you can invoke the scripts like this:

        ./run upload-strings --api-key hlkjhfalksdhf

    Or, after setting the API_KEY environment variable, you can just use:

        ./run upload-strings

    -> SUPER CONVENIENT


SIDENOTES

If you are not using ./run you can still run things like this:

    Command line:


        Create venv:
        
            python3 -m venv env
        
        Install packages:

            ./env/bin/python -m pip install -r <path to requirements.txt>

        Use venv:
    
            1. Option: Use `./env/bin/python` everytime
            2. Option: Activate the venv using `source env/bin/activate.fish` to have `python` work like `./env/bin/python`

        Use .env:
        
            dotenv run -- python <path to script> <args for script>

    VSCode:

        Create venv:
        
            Not possible (?)
        
        Install packages:

            Not possible (?)
            
        Use venv:

            Set the Python Interpreter of VSCode to the one inside your venv (./env/bin/python)
        
        Use  .env:

            Set the `Python: Env File` setting to your .env file.
        
        Pass args:
        
            Add ```"args": ["my", "args"],``` inside .vscode/launch.json
            
            Note:
                DONT ADD API KEYS to .vscode/launch.json. Pass them using environment vars instead.
        
        -> You could use ./run to easily create the venv and install your packages and then run the scripts in VSCode for debugging.
            
        

- If you're not using ./run, you can use the ./.env file from the command line using `dotenv run ...`.
  
    Example:
    
    
- In VSCode, you can easily run scripts without ./run, since:
    1. VSCode loads the ./.env file automatically.
    2. If you  then your installed packages will work, as well!



"""


#
# Dotenv
#

def load_dotenv():
    
    """

    dotenv file explanation:

        A dotenv file defines environment variables to be used with python.

        Why is mac-mouse-fix using it?
        We want to make the shared.py script importable to the other scripts.
        The only way I found to do this such that VSCode code completions work for the shared.py imports 
        is by creating an .env file and putting ```PYTHONPATH=Scripts/Shared/``` into it.
        To use the .env file without vscode, you normally import the `dotenv` library or use the `dotenv`
        command-line-tool, However, you have to install these manually.
        
        Since we want to keep run.py dependency-free, we instead do custom parsing of the .env file inside run.py.

        Custom parsing of the .env file:

            The .env file has a simple syntax that looks like this:
        
                # Application configuration
                APP_NAME=MyCoolApp
                DEBUG=True
                VERSION=1.0.0
                
                # Database configuration
                DATABASE_URL=postgres://user:password@localhost:5432/mydatabase
                                
                # Multiline value using \n
                GREETING=Hello, welcome to MyCoolApp!\nEnjoy your stay.
                
                # Garbage
                THISEQUALS=T=H=A=T
                LOTSOF  =  WHITESPACE
                # comment  =  that should not be parsed
            
            To parse it, we use the regex:

                ^(?!\s*#)(.*?)=(.*)$
            
            You can test it here:

                https://regex101.com/

    """
    
    # Get file content
    content = None
    with open(dotenv_path, 'r') as file:
        content = file.read()
    
    # Apply regex
    regex = r'^(?!\s*#)(.*?)=(.*)$'
    matches = re.finditer(pattern=regex, string=content, flags=re.MULTILINE) # MULTILINE activates ^ and $
    
    # Compile result
    #   Note: We're also stripping out whitespace here
    result = {}
    for match in matches:
        key = match.group(1).strip()
        value = match.group(2).strip()
        result[key] = value
    
    # Return
    return result

#
# Main
#

def main():
    
    # Make sure we're running in the mac-mouse-fix project folder
    assert os.path.basename(os.getcwd()) == 'mac-mouse-fix'

    # Extract --target_repo arg
    #
    #   For this script to run properly, the cwd has to point to the mac-mouse-fix repo. 
    #   When this script is supposed to work on another repo then we can set the --target_repo arg. 
    #
    #   This is intended to be used by the run.py script inside the mac-mouse-fix-website repo.
    
    target_repo = None
    
    repo_arg_index = None
    for i, arg in enumerate(sys.argv):
        if arg == '--target_repo':
            repo_arg_index = i
    
    if repo_arg_index != None:
        target_repo = sys.argv[repo_arg_index+1]
    else:
        target_repo = os.getcwd()
    
    # Log
    print(f"Invoking run.py with cwd: {os.getcwd()}, target_repo: {target_repo}")
    
    # Handle missing subcommand
    if len(sys.argv) < 2:
        print_help_and_exit('run.py: <no subcommand provided>')
        exit(1)
    
    # Process subcommand
    subcommand = sys.argv[1]
    subcommand_args = sys.argv[2:]
    
    # Help
    if subcommand == '-h' or subcommand == 'help':
        print_help_and_exit(subcommand)

    # Unknown command
    if not (subcommand in subcommand_map.keys()):
        print_help_and_exit(subcommand)
    
    # Implement special subcommand
    if subcommand == custom_command_compile_markdown:
        
        # We invoke this script again with different subcommands.
        #   Note: We tried calling ./run instead of `python3 __file__` which should do the same thing, but breaks the VSCode debugger for some reason.
        
        print('\nrun.py: Running sync-strings-internal ...\n')
        subprocess.run(['python3', __file__, 'sync-strings-internal'])
        
        print('\nrun.py: Running markdown-generator-internal ...\n')
        subprocess.run(['python3', __file__, 'markdown-generator-internal', *subcommand_args])
        
        exit(0)
    
    # Find paths
    script_folder = subcommand_map[subcommand]
    requiremements_paths = glob.glob(f'{script_folder}/*.txt')
    script_paths = glob.glob(f'{script_folder}/*.py')
    assert len(requiremements_paths) <= 1
    assert len(script_paths) == 1
    requiremements_path = requiremements_paths[0] if len(requiremements_paths) > 0 else None
    script_path = script_paths[0]
    
    python_interpreter = None
    
    if requiremements_path != None:
        
        # Log
        print(f"\nrun.py: Creating venv at ./{venv_path} ...")
        
        # Create venv
        # Notes: 
        # - subprocess.check_call throws an error if the command returns non-zero. Otherwise returns 0
        # - text=True makes it so we can input the commmand as a single string of text instead of a list of args
        # - shell=True I don't quite understand. Apparently it runs the commans in a 'spawned a shell process' and enables shells features such as pipes and wildcards.
        #   - It apparently also poses a security risk, since e.g. if you pass 'rm -rf /*' then it can delete your entire computer or something
        #   - To create and fill our venv shell=True seems to be necessary.
    
        subprocess.check_call(f"python3 -m venv {venv_path}", text=True, shell=True)
        
        # Get python path for the venv
        venv_python_path = os.path.join(venv_path, 'bin/python')
            
        # Log
        print(f"\n Installing requirements from ./{requiremements_path} ...")
        
        # Install requirements    
        subprocess.check_call(f'./{venv_python_path} -m pip install -r "{requiremements_path}"', text=True, shell=True)
        
        # Tell the WORLD
        python_interpreter = f'./{venv_python_path}'
    
    else:
        python_interpreter = 'python3'
    
    # Log
    print(f"\nrun.py: Loading environ variables from ./{dotenv_path} ...")
    
    # Load environment variables defined in the .env file
    dotenv_vars = load_dotenv()
    
    # Analyze overlap
    overlapping_env_var_keys = [k for k in dotenv_vars.keys() if k in os.environ.keys()]
    dotenv_overlap = {k: dotenv_vars[k] for k in overlapping_env_var_keys}
    os_overlap = {k: os.environ[k] for k in overlapping_env_var_keys}
    
    # Validate
    if len(overlapping_env_var_keys) > 0:
        print(f"\nrun.py: WARN: .env defines vars that are already in the environment:\n.env: {json.dumps(dotenv_overlap, indent=2)}\nos: {json.dumps(dict(os_overlap), indent=2)}")
    
    # Combine env_vars
    env_vars = os.environ | dotenv_vars
    
    # Log
    print(f"run.py: Running script at ./{script_path} with arguments: {subcommand_args} using interpreter {python_interpreter} ...\n")
    
    # Run script
    #   Notes:
    #   - We're passing env= here. If we don't do that, os.environ is automatically passed to the subprocess.
    
    script_result = subprocess.run([python_interpreter, script_path, *subcommand_args], env=env_vars)
    
    # Log 
    #   Log the script output verbatim 
    #   Update: This doesn't seem to work as I thought it would. stdout and stderr were always None, but the called-scripts' prints were printed to the command line anyways.
    # print(f'\nrun.py: script stderr: {script_result.stderr}', end='\n', file=sys.stderr)
    # print(f'run.py: script stdout: {script_result.stdout}', end='\n', file=sys.stdout)
    exit(script_result.returncode)    

#
# Call main
#
if __name__ == "__main__":
    main()