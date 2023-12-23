# Markdown readme

This folder contains stuff for generating user-facing markdown documents. At the time of writing, that's `Acknowledgements.md` and `Readme.md`.

The idea of the stuff in this folder is to generate/update markdown files based on a python script + templates. We use github actions (See `.github/workflows/...`) to automatically run the python scripts. This allows us to do some neat stuff like automatically updating the acknowledgements as people buy the app.

We originally built this stuff in the [`github-actions-test` repo](https://github.com/noah-nuebling/github-actions-test). It contains some additional info and background in it's `Readme-Meta.md` file - which this readme is based upon. It also contains our original draft for the main MMF Readme.md, experiments and info on GitHub actions, and maybe more interesting stuff I forgot.

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

# Install dependencies into python env

You can create a new venv and install the python_requirements.txt file like this: (In fish shell)

``````
python3 -m venv env;\
source env/bin/activate.fish;\
python3 -m pip install -r Markdown/Code/python_requirements.txt;
``````

If you need to install new requirements, you can store them into a requrements.txt using:

```
pip freeze > MarkdownStuff/python_requirements.txt
```

# Using markdown_generator.py

To generate the **acknowledgements** document in different languages based on templates
```
python3 Markdown/Code/markdown_generator.py --document acknowledgements --api_key ***
```

If you don't have the api key:
```
python3 Markdown/Code/markdown_generator.py --document acknowledgements --no_api
```

To generate the **readme** document in different languages based on templates
```
python3 Markdown/Code/markdown_generator.py --document readme
```

# Previewing generated markdown files locally

I use VSCode with the plugin: https://marketplace.visualstudio.com/items?itemName=bierner.markdown-preview-github-styles

# Editing a document

1. Make sure python is installed, create and activate a venv, then install the requirements from Markdown/Code/python_requirements.txt into your venv (see instructions above) (This is necessary in order to run the markdown_generator.py script)
2. Edit the template under Markdown/Templates/
3. Run the markdown_generator.py script which creates an output file based on the template. To see which templates generate which output files see the 'documents' dictionary at the top of the markdown_generator.py script
4. If the output file looks good, create a pull request

# Adding a new document / language

1. Make sure python is installed, create and activate a venv, then install the requirements from Markdown/Code/python_requirements.txt into your venv (see instructions above)
2. Create a new template under Markdown/Templates/
3. Go to the top of the markdown_generator.py script. 1. Add a new entry for your new template to the 'documents' dictionary 2. If you're adding a new language, then add a new entry for your language to the 'languages' dictionary.
4. Run the markdown_generator.py script, which creates an output file based on your new template.
5. If the output file looks good, create a commit and a pull request and stuff

# Online GitHub Actions linting

https://rhysd.github.io/actionlint/

# Localization

https://www.techonthenet.com/js/language_tags.php

Aside from the markdown files, you also might want to localize the Mac Mouse Fix app and the Mac Mouse Fix website.

# Gumroad API

To test the Gumroad sales API (which we use for acknowledgements_generator.py) from the command line:

```
curl --request GET --header "Content-Type: application/x-www-form-urlencoded" --data 'access_token=<SECRET>&product_id=FP8NisFw09uY8HWTvVMzvg==' https://api.gumroad.com/v2/sales | json_pp
```

# Wrap links in markdown which contain spaces with < and > to make them work

See https://superuser.com/a/1517072/1095998

# GitHub Actions

Background
- There's more research notes and stuff in the original [`github-actions-test` repo](https://github.com/noah-nuebling/github-actions-test).
- We looked into various GitHub actions on the marketplace for generating readmes, but it seemed easier to just implement it ourselves.
- IIRC we looked into using GH actions to run the Acknowledgements generation script every time a new copy of MMF is purchased. But we found it impossible for a Gumroad purchase to trigger a GitHub action (research notes in `github-actions-test`), so we decided to just run the update script periodically instead.
- The GitHub action which runs the acknowledgements periodically is called `update-acknowledgements.yml` at the time of writing.
