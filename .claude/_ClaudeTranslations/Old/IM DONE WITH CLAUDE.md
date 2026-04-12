
I'm done.

[Jan 13 2026] I've spent like 2 weeks trying to get a reliable translation workflow with Claude Code. ZERO progress. I haven't translated a SINGLE batch of strings into ANY language. I could micromanage it to output the right strings for simplified Chinese and German but only when MANUALLY micromanaging and pointing out errors, by comparing with human-written translations. I could not get it to do ANY reliable or trustworthy work by itself. So this approach cannot scale to languages where I don't have a means of validating against human-written translations.

I'm going back to human volunteers.
That's its own kind of hell due to my anxiety, but 
at least they have common sense, and can take responsibility, and I do not have to micromanage them. 

God I'm so done.

Also see this commit message where I crashed out and described some more issues: 7d7353e00da723b4abd273e727aafcaaadd5dd0d

Counterarguments: 

- Maybe I just need to stop trying to micromanage it. It mostly produces reasonable, usable translations, that ignore only SOME of the constraints and are generally worse than what the humans already wrote. However, for languages where we don't have human translators, yet (or where the human translators themselves are not very good) maybe this is better than nothing. 
    -> Counter: That makes the whole thing EVEN MORE complicated. I thought I could simplify things by just HAVING THE AI do all the work, after micromanaging it into good German translations. But instead, I would have to still interact with humans (my cryptonite) to actually get good translations, but then ADDITIONALLY micromanage a Claude, that wont EVER properly follow all the instructions anyways (which is very frustrating) just to get second-rate translations. I hate everything. 
- Maybe I should try the old 'adding-translations' skill again (with the context-expansion stuff). That actually produced perfect German and Chinese translations in some cases IIRC (See 7d7353e00da723b4abd273e727aafcaaadd5dd0d)
- Maybe Claude 4.5 Opus is periodically nerfed. People on the internet started saying this, I think only after I rewrote 'adding-translations'. (After which, IIRC, I could never get it to do any batch of strings right without micromanaging.)
    - Example: https://www.reddit.com/r/ClaudeAI/comments/1qb4j7u/claude_opus_output_quality_degradation_and/
    - Counter: Might be mass-hysteria
    - Personal memories: 
        - When testing Opus 4.5 initially, I did feel like it had much better 'common sense' and was more trustworthy than other models. When I accidentally used Sonnet I noticed very quickly, because it was so untrustworthy and annoying in comparison. Opus was the first time I trusted an LLM to do decent work and make reasonable decisions by itself. -> OPPOSITE of how I'm feeling now.
            - Counter: Workflow has changed (from coding mfstrings.py to just translation), but can that really explain the stark difference?
- Maybe there is something I'm missing about the Claude Code workflow that the Claud experts do: 
    - Discussion about micromanagement and parallelization: https://x.com/amorriscode/status/2009417425000034742
        - (I don't understand exactly what they mean. They're either being vague or I'm dumb)



UPDATE: [jan 14 2026]

I tried just making a standalong subagent for glossary research. Spent the WHOLE FUCKING DAY. Can not get it to produce reasonable output for a single batch of German strings. (The trigger.* strings).
    -> The problem is it finds lots of 'bewegen' translations for 'drag' and then translates as 'klicken und bewegen' instead of 'klicken und ziehen' which is completely retarded. It consistently, always does this. I cannot get it stop doing this. I think it just finds more examples, and it doesn't understand that the context is different.

    -> Update 2: Actually made it work later that day. Phew. Produces reasonable output for the trigger.* strings in German and simplified Chinese.

---


Some old notes:


    **Example**: Suppose `dialog.label.foo` says "capitalization should follow `header.label.*`":
    1. `header.label.*` are direct dependencies (establish the style to follow)
    2. Check if `header.label.*` belongs to a larger prefix group (e.g., `header.*`)
    3. If `header.*` strings share rules (check their comments), add ALL of `header.*` to your list
    4. Check if they're translated for your locale
    5. If not: translate the entire `header.*` group FIRST, then translate `dialog.label.*`

    **Key insight**: Dependencies aren't just for understanding rules - they're strings that must be translated first to establish consistent terminology and style. If string A says "match the style of string B", you cannot translate A correctly until B exists. And if B is part of a larger group, that entire group must be translated first.




    (This will make it do internet searches which greatly slow down the workflow)
    (Update: It still does it AAHHAGHGH. It never did this yesterday, with the same prompts, I think)

    - **Follow Apple's style** - This is a macOS app. Follow Apple's terminology and style guides where possible. Use the same terms that appear in System Settings, Finder, and other Apple apps for your locale.