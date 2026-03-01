# Conclusion

[Mar 1 2026]

Finally done with the first batch of strings. This took me absolutely forever.

The base workflow:
    - Starting with languages that are easiest to review (because I speak them/read them a little or because we have human translations to compare against)
    - Building up a 'context document' with all the corrections we made during review and giving that to future translator Claudes as context.
-> this works. 
But we should probably stop reviewing in-depth for the hard-to-review languages (where we don't have human-backing)
That felt like a waste of time. We didn't find many improvements. I think it's:
    - In part because the Claude wrote genuinely good translations with good judgement after the 'context document' was more filled out.
    - The hard-to-review languages are – hard to review. So I had to learn a lot and trust Claude a lot to explain things and judge things for me.
        - I think it's very plausible that there were many bad decisions we missed – but when reviewing with Claude in this way, we just didn't really find many, even after spending a lot of time.
Caveat: I might be misremembering – we may have found improvements earlier that I forgot about. (I got bored and did sideprojects for a while halfway through.) [Mar 1 2026]

I think the future string batches will go faster and more smoothly, because:
    - The trigger.* strings were probably the hardest strings in the entire project, because lots of (at times conflicting) constraints with nuanced judgement calls to be made. Constraints such as:
        - Following Apple's macOS glossary, but also deviating when appropriate, staying very concise and scannable, dipping into a telegraphic style, but without sounding too unnatural. Staying internally conistent, but allowing some inconsistencies to avoid verboseness. The strings being stitched together programmatically, and having to make sense grammatically, with different word orders and connecting particles/connecting grammatical cases, understanding the context of the Action Table where these strings appear (they are descriptions not commands). Preserving markdown formatting for greying out button names that match grouprow header strings, but not greying out the grammatical connector words in the button strings ... and more. It's a lot of stuff. ... Honestly impressive that Claude did such a good job now that I think about how complicated this is.
    - I know have confidence (/resignation) to trust Claude Opus 4.5 for the hard-to-review languages.
    - Most other strings also aren't as central to the user experience – so it's easier to let go a little but.
        - (The trigger.* strings are on the Action Table which is the most interactive and powerful UI element in the app – and much of the terminology established there is used throughout the project.)
    - Hopefully won't get borded / sidetracked with sideprojects since I won't feel like I'm wasting as much time trying to review the 'hard-to-review' languages.