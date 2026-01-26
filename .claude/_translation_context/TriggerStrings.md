# Translation Context for trigger.* Strings

## Overview

You are translating strings for **Mac Mouse Fix**, a macOS app that enhances mouse functionality. These `trigger.*` strings appear in the **Action Table** UI, where the left column shows triggers (user inputs) and the right column shows effects (what happens).

## Target Language

**[TO BE FILLED BY INVOKER]**

## The mfstrings Tool

Use `./run mfstrings edit` to write translations:

```bash
# Edit a translation value and mark as translated
./run mfstrings edit --path 'Localizable/KEY/LOCALE' --state 'translated' --value 'new text'
```

Example:
```bash
./run mfstrings edit --path 'Localizable/trigger.substring.click.1/de' --state 'translated' --value '%@ klicken'
```

**Important:** Use single quotes for `--value`. Double quotes can corrupt format specifiers.

If you need to inspect strings:
```bash
./run mfstrings inspect --cols key,en,LOCALE --sortcol key --filter fileid=Localizable | grep "trigger\."
```

## Strings to Translate (25 total)

**First, look up the current English strings and existing translations:**
```bash
./run mfstrings inspect --cols key,en,LOCALE --sortcol key --filter fileid=Localizable | grep "trigger\."
```
(Replace `LOCALE` with your target locale, e.g., `de`, `fr`, `zh-Hans`)

### String Categories

**Button Names (4)** — `trigger.substring.button-name.*`
- `trigger.substring.button-name.middle`
- `trigger.substring.button-name.numbered`
- `trigger.substring.button-name.primary`
- `trigger.substring.button-name.secondary`

**Button Modifiers (3)** — `trigger.substring.button-modifier.*`
These appear when chaining actions. Example: "Click Button 4 + Double Click Button 5"
- `trigger.substring.button-modifier.1`
- `trigger.substring.button-modifier.2`
- `trigger.substring.button-modifier.3`

**Click Actions (3)** — `trigger.substring.click.*`
- `trigger.substring.click.1`
- `trigger.substring.click.2`
- `trigger.substring.click.3`

**Drag Actions (4)** — `trigger.substring.drag.*`
- `trigger.substring.drag.1`
- `trigger.substring.drag.2`
- `trigger.substring.drag.3`
- `trigger.substring.drag.flags`

**Hold Actions (3)** — `trigger.substring.hold.*`
- `trigger.substring.hold.1`
- `trigger.substring.hold.2`
- `trigger.substring.hold.3`

**Scroll Actions (4)** — `trigger.substring.scroll.*`
- `trigger.substring.scroll.1`
- `trigger.substring.scroll.2`
- `trigger.substring.scroll.3`
- `trigger.substring.scroll.flags`

**Group Row Button Names (4)** — `trigger.y.group-row.button-name.*`
Used as headers to group actions by button. These are auto-capitalized by the UI.
- `trigger.y.group-row.button-name.middle`
- `trigger.y.group-row.button-name.numbered`
- `trigger.y.group-row.button-name.primary`
- `trigger.y.group-row.button-name.secondary`

## Critical Constraints

### 1. Lowercase (for most languages)
The `trigger.substring.*` strings are **joined programmatically** to create combined strings. The final combined string is auto-capitalized at the start.

**Therefore:** Keep all substrings lowercase (unless your language has specific capitalization rules that require otherwise).

Example of how strings combine:
- "Double Click %@ +" + "Click and *Drag* %@" → "Double Click Button 4 + Click and *Drag* Button 5"

### 2. Descriptive Tone (not imperative)
Translate these as **descriptions of actions** rather than commands.
- Good: "(to) click and drag" 
- Avoid: "please click and drag" / "click and drag!"

### 3. Preserve Markdown Emphasis
Keep the `*asterisks*` around Drag and Scroll for UI rendering:
- `*Drag*` → `*[translated]*`
- `*Scroll*` → `*[translated]*`

### 4. Preserve %@ Placeholder
The `%@` gets replaced with button names (or may be empty). Keep it in the appropriate position for your language's grammar.

### 5. Use Apple's macOS Terminology
This is a macOS app. Match Apple's official terminology as it appears in System Settings, macOS UI, and Apple documentation. Use your knowledge of Apple's localized terms from your training data or spawn a glossary-research subagent. 

Key terms to match Apple's style:
- Click / Double Click / Triple Click
- Drag
- Scroll  
- Hold
- Primary Button / Secondary Button / Middle Button
- Button (numbered)

### 6. Consistency
The `trigger.substring.button-name.*` strings and `trigger.y.group-row.button-name.*` strings should use identical translations (both are auto-capitalized or lowercase as appropriate).

### 7. Simplicity
**Strongly prefer shorter, simpler translations.** Avoid unnecessary words. Shorter strings work better in UI and are easier to read.

## Instructions

1. Translate all 24 strings listed above
2. Use the `./run mfstrings edit` command for each string
3. Set `--state 'translated'` for each
4. DO NOT invoke the adding-translations skill
5. When done, report back with a summary of your translations

Good luck!

## Desired translations

The rest of this document is designed to help you make your own decisions about how to translate into ANY language.
But for some texts, I found it helpful to specify the desired translations directly.

The 'Explanation' sections may help you choose translations for other languages, by using the same guiding principles.

German
    Desired Translation: Translate 'Button' as 'Taste' instead of 'Maustaste'.
        Explanation: In the glossary, you'll find 'Button' translated as 'Taste' or 'Maustaste'. 'Maustaste' is more frequent. But since we strongly prefer simplicity, we choose 'Taste' instead. Given the context of where these strings appear in the UI ('Action Table' on the 'Buttons Tab' in the 'Mac Mouse Fix' app) it's clear that 'Taste' doesn't refer to a keyboard key, so the longer 'Maustaste' is not necessary to disambiguate.
Chinese
    Desired Translation: Translate the button names as 主键, 辅键, 中键, and 第%@键
        Explanation: In the glossary you'll find various Chinese translations for the mouse buttons like '按钮%@', '第3键', '鼠标第%@键' and '鼠标主按钮'. The above choices are very short while staying natural and consistently using '键'.
Korean
    Desired Translation: Translate the button names as 주 버튼, 보조 버튼, 중간 버튼, %@번 버튼
        Explanation: These are optimized for length. Except for `%@번 버튼`, which we're using over `버튼 %@` since it's more natural and has consistent word order with the other strings.
    Desired Translation: Translate 'Hold' (as in 'Double Click and Hold Button 4') as '길게 누름'. 
        Explanation: Apple uses '길게 누르기' pretty consistently but '길게 누름' is slightly shorter while still sounding natural (I'm not actually sure this is the best choice – but lets go with it for now.)
Turkish
    Desired Translation: Translate 'Button' as 'düğmeyi' instead of 'düğme' (in the 'trigger.substring.button-name.*' strings.)
        Explanation: Some of the trigger.substring.* strings have %@ format specifiers where button names will be inserted. In Turkish, we need to add inflections to make the joined strings grammatically correct. düğmeyi seemed like the best choice among other possible inflections like düğmesine or düğmesini. (Not sure if that's the best possible choice, but let's roll with it for now)
        Desired Translation: Translate 'Button %@' as '%@. düğmeyi' instead of 'düğme %@' (in the trigger.substring.button-name.* strings.)
            Explanation: Grammar (see above)
Multiple Languages
    Desired Translation: Grammatical connectors in `trigger.substring.button-name.*` strings.
        Explanation: The `trigger.substring.button-name.*` strings are inserted into the other `trigger.substring.*` strings at the format specifiers (%@). The combined strings needs to feel grammatically sound. In some languages this requires connectors.
        By language:
            French: Use "du" (of the)       
                → "du *bouton central*", "du *bouton %@*", "du *bouton principal*", "du *bouton secondaire*"
                    Reasoning: "du" is shorter than "sur le" while still sounding natural (I hope). "du" is also more semantically sound for some strings ('Click and Drag *of* the Middle Button' is more reasonable than 'Click and Drag *on* the Middle button)
            Czech: Use genitive case (expresses "of", like French "du")
                → "*středního tlačítka*", "*tlačítka %@*", "*primárního tlačítka*", "*sekundárního tlačítka*"
                    Note: Genitive case endings differ from nominative, so these won't match the group-row headers exactly.
            Russian: Use genitive case (expresses "of", like French "du")
                → "*средней кнопки*", "*кнопки %@*", "*основной кнопки*", "*вспомогательной кнопки*"
                    Note: Genitive case endings differ from nominative, so these won't match the group-row headers exactly.
            Other languages:
                Some other languages like Spanish and Portuguese also use such grammatical connectors, but we prefer to keep things simple and decided we could get away without them. 
        Note: We decided English does NOT need "the" and that "Click Middle Button" (instead of "Click the Middle Button") feels like acceptable UI shorthand.
        Note to self: We also added comments about this to 
            trigger.substring.button-name.middle AND 
            trigger.substring.click.1 
            (So I'm not sure explaining it again here is useful.)