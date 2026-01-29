# Translation Workflow Notes for Future Claudes

## Lessons Learned During Brazilian Portuguese Translation Review (2026-01-04)

### When reviewing translations:

1. **Flag uncertainties about technical details**
   - If you're unsure about something technical (like CFBundleName behavior, whether .app filenames get localized, etc.), notify the user
   - Ask if it should be documented in the localization context/comments
   - Don't just make assumptions - document the uncertainty
   - Example: We weren't sure if "Mac Mouse Fix Helper.app" should be translated or kept in English. Turned out CFBundleName controls the Finder display name and it IS localized.

2. **Mark inconsistencies found during context gathering**
   - While searching for context, if you spot other strings with similar issues, mark them as 'needs_review'
   - Example: Found "Mac Mouse Fix Helper.app" left in English in a tooltip while checking consistency
   - Example: Found the Portuguese translation line itself still in English in the Acknowledgements

3. **Use grep/search to verify consistency**
   - When reviewing a term, grep for ALL occurrences across the project
   - Check both the term being translated AND related terms
   - Example: Searching "Mac Mouse Fix Helper" revealed it should consistently be "Assistente do Mac Mouse Fix"

4. **Check comments for critical context**
   - Comments often contain important notes about:
     - Technical limitations (CFBundleName, format specifiers, etc.)
     - Related strings to check for consistency
     - Layout constraints
     - Where to find official Apple translations

5. **Sort by key/comment as needed**
   - Sorting by 'key' groups strings in the order they appear on the website/app
   - Some files (like 'Main') should be sorted by 'comment' instead
   - Comments usually tell you which sorting is best

6. **Simplicity and matching the source**
   - When reviewing, don't just aim for consistency with existing translations
   - Also consider: "Could this be simpler? Does it need to deviate from the English?"
   - Bias towards: **Keep things simple** and **match the English version, unless your deviation makes things better**
   - Example: "5 ou mais botões" (5 or more buttons) was technically correct and consistent, but "5+ botões" is simpler, shorter, and matches the English better
   - Don't be afraid to suggest simplifications even if the current translation is "correct"
   - Ask: "Is this translation doing extra work that doesn't add value?"

7. **Autonomous work with uncertainty flagging**
   - Work through translations autonomously, making fixes where you're confident
   - When you encounter uncertainties, mark them as 'needs_review' and continue
   - Report uncertainties to the human (either as you go, or batch them up - whatever works best)
   - Challenge: In longer sessions, you may need to remember WHY you flagged something as uncertain
   - Goal: Human should understand your reasoning when they review flagged items
   - This allows bulk translation work without constant interruptions

## Common Issues Found:

- Inconsistent translation of app names ("Ajudante do Controlador..." vs "Assistente")
- Mixed English/Portuguese in the same string
- .app filenames left in English when they should match CFBundleName
- Missing translations in meta-content (like the Portuguese translation credit line being in English)

## Tools Usage:

- `./run mfstrings inspect --fileid all --cols state:pt-BR,fileid,key,en,pt-BR --sortcol key --pretty` - main inspection
- `./run mfstrings inspect --fileid all --cols en,pt-BR --sortcol key | grep "term"` - consistency checking
- `./run mfstrings edit --path "fileid/key/pt-BR" --state "needs_review"` - mark for review
- `./run mfstrings edit --path "fileid/key/pt-BR" --value "new text" --state "translated"` - fix and mark done
