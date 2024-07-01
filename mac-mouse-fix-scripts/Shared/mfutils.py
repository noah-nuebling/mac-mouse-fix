"""

utlis.py holds various utility functions 
    of categories that are too small to put into a separate file

"""

#
# Imports
#

# pip imports

# stdlib imports  
import tempfile
import subprocess
import os
import textwrap
import json
import random
            

#
# Command line tools
#

def clt_result_description(completed_process: subprocess.CompletedProcess) -> str:
    
    result = f"""\
        
code: {completed_process.returncode}

stdout:
{add_indent(completed_process.stdout, 2)}
[[endstdout]]

stderr:
{add_indent(completed_process.stderr, 2)}
[[endstderr]]

"""
    
    return result
    
def runclt(command, cwd=None):
    
    """
    Secure variant of the runclt_insecure method.
    - shell=False makes this secure
    """
    # Preprocess `command`
    #   -> So that it works similar to as if shell=True (we can pass in the args as a single string) but yet we can keep shell=False
    #   -> If one of your args contains spaces, escape it like this: 
    #       .replace(' ', '\ ')
    
    commands = None
    if type(command) is str:
        commands = command.split(' ')
    elif type(command) is list:
        commands = command
    
    # Code from runclt_insecure
    success_codes=[0]
    if commands[0] == 'git' and commands[1] == 'diff': 
        success_codes.append(1) # Git diff returns 1 if there's a difference
    
    clt_result = subprocess.run(commands, cwd=cwd, shell=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert clt_result.stderr == '' and clt_result.returncode in success_codes, f"Command \"{command}\" was run in cwd \"{cwd}\" and failed with result:\n{ clt_result_description(clt_result) }"
    
    clt_result.stdout = clt_result.stdout.strip() # The stdout sometimes has trailing newline character which we remove here.
    
    return clt_result.stdout

def runclt_insecure(command, cwd=None, exec=None): 
    
    """
    Notes:
    
    This is a SECURITY PROBLEM.
    -> What makes this insecure is if we set shell=True on subprocess.run and then pass in user-generated strings. 
        (If you don't pass in user generated strings, this is ok to use)
    -> We replaced this with runclt(), renamed this func to runclt_insecure() and added these notes about security in the commit after b052473ad4a5efd9128f2934daf15bdbd0daf8a7
    
    Args that we're passing to subprocess.run():
    - `shell=True`: Pass the args through a shell instead of invoking the clt directly. 
        -> This allows you to pass the clt and args in a single string and also use several commands using ; or use shell features like | pipes.
        -> If you turn this off, you have to pass the clt and args as a list of strings, which is annoying.
        -> However, this is a SECURITY PROBLEM if we pass in any user-generated strings. -> Never use this without considering security
    - `text=True`: Return stdout and stderr as string instead of bits
    - `cwd=cwd`: Set the current working directory, which is passed to the CLT
    - `executable=exec`: Replaces the program to execute. 
        -> If shell=True, then this replaces the shell I think. Otherwise, I'm not sure.
        -> We used to have this set to exec='/bin/bash'
        -> I don't think we should set this
        
    """
    
    assert False
    
    success_codes=[0]
    if command.startswith('git diff'): 
        success_codes.append(1) # Git diff returns 1 if there's a difference
    
    clt_result = subprocess.run(command, cwd=cwd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, executable=exec)
    
    assert clt_result.stderr == '' and clt_result.returncode in success_codes, f"Command \"{command}\", run in cwd \"{cwd}\"\nreturned: {clt_result_description(clt_result)}"
    
    clt_result.stdout = clt_result.stdout.strip() # The stdout sometimes has trailing newline character which we remove here.
    
    return clt_result.stdout

def run_git_command(repo_path, command):
    
    """
    Helper function to run a git command using subprocess. 
    (Credits: ChatGPT)
    
    Should probably unify this into runCLT, along with other uses of `subprocess`
    """
    proc = subprocess.Popen(['git', '-C', repo_path] + command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()

    if proc.returncode != 0:
        raise RuntimeError(f"Git command error: {stderr.decode('utf-8')}")

    return stdout.decode('utf-8')


#
# Strings
#

def add_indent(s, indent_spaces=2):
    return textwrap.indent(s, ' ' * indent_spaces)

def get_indent(string: str) -> tuple[int, chr]:
    
    # NOTE: We could possibly use textwrap.dedent() etc instead of this
    
    # Split into lines
    lines = string.split('\n')
    
    # Remove lines empty lines (ones that have no chars or only whitespace)
    def is_empty(string: str):
        return len(string) == 0 or all(character.isspace() for character in string)
    lines = list(filter(lambda line: not is_empty(line), lines))
    
    indent_level = 0
    break_outer_loop = False
    
    while True:
        
        # Idea: If all lines have a an identical whitespace at the current indent_level, then we can increase the indent_level by 1. 
        #   Note: GitHub Flavoured Markdown apparently considers 1 tab equal to 4 spaces. Don't know how we could handle that here. We'll just crash on tab.
        
        last_line = None
        for line in lines:
            
            assert line[indent_level] != '\t' # Tabs are weird, we're not sure how to handle them.
            
            is_space = line[indent_level].isspace()
            is_differnt = line[indent_level] != last_line[indent_level] if last_line != None else False
            if not is_space or is_differnt : 
                break_outer_loop = True; break;
            last_line = line
        
        if break_outer_loop:
            break    
        
        indent_level += 1
    
    indent_char = None if indent_level == 0 else lines[0][0]

    return indent_level, indent_char

def set_indent(string: str, indent_level: int, indent_character: chr) -> str:
    
    # Get existing indent
    old_level, old_characer = get_indent(string)
    
    # Remove existing indent
    if old_level > 0:
        unindented_lines = []
        for line in string.split('\n'):
            unindented_lines.append(line[old_level:])
        string = '\n'.join(unindented_lines)
    
    # Add new indent
    if indent_level > 0:
        indented_lines = []
        for line in string.split('\n'):
            indented_lines.append(indent_character*indent_level + line)
        string = '\n'.join(indented_lines)
    
    # Return
    return string
    
    
#
# Files
#

def create_temp_file(suffix=''):
    
    # Returns temp_file_path
    #   Use os.remove(temp_file_path) after you're done with it
    
    temp_file_path = ''
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
        temp_file_path = temp_file.name
    return temp_file_path

def read_file(file_path, encoding='utf-8'):
    
    result = ''
    with open(file_path, 'r', encoding=encoding) as temp_file:
        result = temp_file.read()
    
    return result
    

def read_tempfile(temp_file_path, remove=True):
    
    result = read_file(temp_file_path)
    
    if remove:
        os.remove(temp_file_path)
    
    return result

def write_file(file_path, content, encoding='utf-8'):
    with open(file_path, 'w', encoding=encoding) as file:
        file.write(content)

def convert_utf16_file_to_utf8(file_path):
    
    content = read_file(file_path, 'utf-16')
    write_file(file_path, content, encoding='utf-8')

def is_file_empty(file_path):
    """Check if file is empty by confirming if its size is 0 bytes.
        Also returns true if the file doesn't exist."""
    return not os.path.exists(file_path) or os.path.getsize(file_path) == 0

#
# Other
#

def xcode_project_uuid():
    
    """
    The project.pbxproj file from Xcode uses 12 digit hexadecimal numbers (which have 24 characters) as keys/identifiers for it's 'objects'. So here we generate such an identifier. (In a really naive way)
    """
    
    result = ""
    for _ in range(24):
        num = random.randint(0, 15)
        hexa = hex(num)[2:].capitalize()
        result += hexa
    
    assert(len(result) == 24)
    
    return result
    
    