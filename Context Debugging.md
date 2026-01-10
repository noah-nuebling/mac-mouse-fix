
(Notes for operating Claude Code to translate the repo.)


# Prompt

Hi Claude! 

Lets translate the following strings in the Localizable file into German (de):

capture-toast.button-name.middle
capture-toast.button-name.numbered
capture-toast.button-name.primary
capture-toast.button-name.secondary
capture-toast.buttons.captured.body|==|one
capture-toast.buttons.captured.body|==|other
capture-toast.buttons.captured.hint|==|one
capture-toast.buttons.captured.hint|==|other
capture-toast.buttons.link
capture-toast.buttons.uncaptured.body|==|one
capture-toast.buttons.uncaptured.body|==|other
capture-toast.scroll.captured.body
capture-toast.scroll.link
capture-toast.scroll.uncaptured.body


# Supervise

Compare Claude's German translations against mine:


./run mfstrings inspect --cols key,fileid,comment,en,de,state:de --sortcol key --pretty --diff-filter HEAD --diff-highlight 72ca917f9,472bb34 --filter fileid=Localizable

(72ca917f9 -> Last commit in mac-mouse-fix         before deleting handwritten translations)
(472bb34   -> Last commit in mac-mouse-fix-website before deleting handwritten translations)

# Iterate

## Ask Claude to help after spotting errors:

Wait wait. That looks like a good correction, but the goal is to try to improve the initial context that you were provided, so that this wouldn't have happened. Then, we could let future Claudes run on all sorts of different languages, and be pretty confident that they would find the references as well (and translate things to a very high quality standard)

Can you help me with that?


## Improve

Improve 
- adding-translations/SKILL.md
- translation-review/SKILL.md
- The comments in the .xcstrings files

## Restart

- Stash / discard .xcstrings changes.
    - ./run mfstrings bulk-edit delete --locale de --force
-  Start again.