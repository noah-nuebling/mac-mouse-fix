# Markdown readme

Note:
- The strings in Markdown.xcstrings are set to 'manual' to prevent Xcode from deleting them. However they are actually managed by our mac-mouse-fix-scripts scripts and updated based on the markdown templates. Any manual edits will be overridden!

# vvv This is all old and probably outdated vvv

This folder contains stuff for generating user-facing markdown documents. At the time of writing, that's `Acknowledgements.md` and `Readme.md`.

The idea of the stuff in this folder is to generate/update markdown files based on a python script + templates. We use github actions (See `.github/workflows/...`) to automatically run the python scripts. We're currently using this to automatically update the acknowledgements as people buy the app. The readme isn't automatically rendered through GitHub Actions at the moment.

We originally built this stuff in the [`github-actions-test` repo](https://github.com/noah-nuebling/github-actions-test). It contains some additional info and background in it's `Readme-Meta.md` file - which this readme is based upon. It also contains our original draft for the main MMF Readme.md, experiments and info on GitHub actions, and maybe more interesting stuff I forgot.


# Compiling the documents

### 1. Install dependencies into python env

In order to run `markdown_generator.py`, you need to install the dependencies first. To do this, you can create a new virtual environment (venv) and then install the requirements into the venv from the `python_requirements.txt` file. To do this use the following terminal commands: 

**Commands for fish shell** (zsh shell is the macOS default)
``````
python3 -m venv env;\
source env/bin/activate.fish;\
python3 -m pip install -r Markdown/Code/python_requirements.txt;
``````

If you need to install new requirements, you can store them into a requrements.txt using:

```
pip freeze > MarkdownStuff/python_requirements.txt
```

### 2. Run markdown_generator.py to compile templates

#### Acknowledgements

To generate the **acknowledgements** document in different languages based on templates
```
python3 Markdown/Code/markdown_generator.py --document acknowledgements --api_key ***
```

If you don't have the api key:
```
python3 Markdown/Code/markdown_generator.py --document acknowledgements --no_api
```

#### Readme

To generate the **readme** document in different languages based on templates
```
python3 Markdown/Code/markdown_generator.py --document readme
```

# Other


#### Previewing generated markdown files locally

I use Visual Studio Code with the plugin: https://marketplace.visualstudio.com/items?itemName=bierner.markdown-preview-github-styles

#### Online GitHub Actions linting

https://rhysd.github.io/actionlint/

#### Localization

See the MMF Localization Guide: https://github.com/noah-nuebling/mac-mouse-fix/discussions/731

#### Gumroad API

To test the Gumroad sales API (which we use for `markdown_generator.py`) from the command line:

```
curl --request GET --header "Content-Type: application/x-www-form-urlencoded" --data 'access_token=<SECRET>&product_id=FP8NisFw09uY8HWTvVMzvg==' https://api.gumroad.com/v2/sales | json_pp
```

#### Wrap links in markdown which contain spaces with < and > to make them work

See https://superuser.com/a/1517072/1095998

# GitHub Sponsors

At the time of writing, we're not listing GitHub sponsors in Acknowledgements. It should be possible with a graphql query like this:

```graphql
query {
	user(login: "sindresorhus") {
    
    sponsorshipsAsMaintainer(last: 100, activeOnly: true) {
      nodes {
        tierSelectedAt
        tier {
          id
          name
        }
        sponsorEntity {
          ... on User {
            login
            
          }
          ... on Organization {
            login
          }
        }
      }
    }
```

See GitHub [GraphQL API Explorer](https://docs.github.com/en/graphql/overview/explorer.)


! We're also not listing people who contributed pull-requests. Maybe we should do that?

# GitHub Actions

Background
- There's more research notes and stuff in the original [`github-actions-test` repo](https://github.com/noah-nuebling/github-actions-test).
- We looked into various GitHub actions on the marketplace for generating readmes, but it seemed easier to just implement it ourselves.
- IIRC we looked into using GH actions to run the Acknowledgements generation script every time a new copy of MMF is purchased. But we found it impossible for a Gumroad purchase to trigger a GitHub action (research notes in `github-actions-test`), so we decided to just run the update script periodically instead.
- The GitHub action which runs the acknowledgements periodically is called `update-acknowledgements.yml` at the time of writing.
