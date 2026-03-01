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

### 2. Descriptive Tone (not instructive)

Translate these as **UI labels describing actions** rather than instructions for the user.
- Good: "(to) click and drag" 
- Bad: "(please) click and drag" / "(you should) click and drag(!)"

Motivation:
In German, commands in macOS typically use infinitive (Wiederholen, Widerrufen) and using 
imperative (Wiederhole, Widerrufe) would sound awkward, and not appropriately 'descriptive',
even though both are correct literal translations of (Redo, Undo). 
The same thinking applies to the trigger.* strings (in German)

Consider this German example when choosing the tone and grammatical structure for your translations.

### 3. Preserve Markdown Emphasis
Keep the `*asterisks*` around Drag and Scroll for UI rendering:
- `*Drag*` → `*[translated]*`
- `*Scroll*` → `*[translated]*`

### 4. Think about the %@ placeholders

`%@` gets replaced with button names, or it may be empty.

Make sure the combined strings make grammatical sense in both cases:
    1. A button name is inserted for `%@` 
    2. Empty string `@""` is inserted for `%@`

You can insert grammatical inflections into the substrings (e.g. we're using `du *bouton principal*` in French)

But we also strongly value conciseness. So a slightly telegraphed style is acceptable if it's not too wrong-sounding in the target language.
(E.g. we're using `Click Middle Button` instead of `Click the Middle Button` in English, but in French, we decided omitting `du` would sound too wrong.)

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
Chinese (Simplified)
    Desired Translation: Translate the button names as 主键, 辅键, 中键, and 第%@键
        Explanation: In the glossary you'll find various Chinese translations for the mouse buttons like '按钮%@', '第3键', '鼠标第%@键' and '鼠标主按钮'. The above choices are very short while staying natural and consistently using '键'.
Chinese (Traditional)
    Desired Translation: No spaces around button names. ('按下%@' instead '按下 %@')
        Explanation: Spaces aren't typically used like this in Chinese. The button names are short and already visually distinct (grayed out in UI), so spaces aren't needed for scannability.
    Desired Translation: Use 按下 instead of 按一下 for 'Click'.
        Explanation: Apple seems to use 按一下 more, but they also use 按下 and that's shorter. 
            We hope it's still clear/natural in context.
            (Not sure this was the best decision but let's roll with it for now.)
            (Additional thought: [Feb 2026] Maybe my intuition for omitting 'single' stems from English scannability concerns which don't apply to Chinese since there are so much fewer characters)
    Desired Translation: Translate the button names as 主鍵, 輔鍵, 中鍵, and 第%@鍵
        Explanation: Apple's zh-Hant glossary uses longer forms (主要按鈕, 輔助按鈕, 滑鼠中間按鈕, 按鈕%@). An earlier human translator also chose these longer forms.
            We decided to deviate because we value conciseness. Plus, Apple also uses 鍵 in mouse contexts (I found 點按左鍵, 點按右鍵 for "Left Click", "Right Click"), so we think (hope) it won't feel out of place here.
            (Not sure this was the best choice. But let's roll with it for now.)
            (Sidenote: The names happen to parallel the button names found in the *zh-Hans* glossary (主键, 辅键, 中键, 第%@键) – but that's not why we chose them.)
Korean
    Desired Translation: Translate the button names as 주 버튼, 보조 버튼, 중간 버튼, %@번 버튼
        Explanation: These are optimized for length. Except for `%@번 버튼`, which we're using over `버튼 %@` since it's more natural and has consistent word order with the other strings.
    Desired Translation: Translate 'Hold' (as in 'Double Click and Hold Button 4') as '길게 누름'. 
        Explanation: Apple uses '길게 누르기' pretty consistently but '길게 누름' is slightly shorter while still sounding natural (I'm not actually sure this is the best choice – but lets go with it for now.)
Japanese
    Desired Translation: Use no (の) as a grammatical connector in the button names ('trigger.substring.button-name.*') instead of wo (を)
        Explanation: の creates noun phrases ("click of the primary button") while を creates action phrases ("click the primary button"). We thought の fits better with the 'descriptive' (not instructive) tone. 
            We found Apple using の in (somewhat?) similar contexts. e.g.: 
                "Secondary click"     → "副ボタンのクリック"
                "Double Click Action" → "ダブルクリックのアクション"
            (Not sure this is the best choice, but lets roll with it for now.)
Hungarian
    Desired Translation: Translate 'Hold' as 'tartás' instead of 'lenyomva tartás' or 'nyomva tartás'.
        Explanation: Apple's glossary shows all 3, but the glossary-research agent didn't find the shorter standalone form 'tartás' (which we prefer due to brevity)
Turkish
    Desired Translation: Translate 'Button' as 'düğmeyi' instead of 'düğme' (in the 'trigger.substring.button-name.*' strings.)
        Explanation: Some of the trigger.substring.* strings have %@ format specifiers where button names will be inserted. In Turkish, we need to add inflections to make the joined strings grammatically correct. düğmeyi seemed like the best choice among other possible inflections like düğmesine or düğmesini. (Not sure if that's the best possible choice, but let's roll with it for now)
        Desired Translation: Translate 'Button %@' as '%@. düğmeyi' instead of 'düğme %@' (in the trigger.substring.button-name.* strings.)
            Explanation: Grammar (see above)
Portuguese (pt-PT and pt-BR)
    Desired Translation: Prefer infinitives, but use a noun for 'clique' (`clique e *arrastar* %@`, `clique duplo e segurar %@`, ...)
        Explanation: In Portuguese, Apple likes to use infinitives for action-describing UI labels (e.g. Desfazer, Refazer in the MainMenu).
            We *want* to use infinitives, too, but there's a problem: "duplo clicar" and "triplo clicar" don't work in Portuguese.
            Therefore we use "duplo clique" and "triplo clique" instead, which means we mix nouns + infinitives (`clique e *arrastar* %@`). We think this is a bit awkward but not too bad.
            We chose to use "clique" (over "clicar") even for single-clicks, to keep it consistent with "duplo clique" and "triplo clique". (Not sure if that's the best choice, but lets roll with it for now.)
Ukrainian
    Desired Translation: Use 'і' over 'й' in the `trigger.substring.*.flags` strings. ('і *перетягування*', 'і *прокрутка*')
        Explanation: These strings get appended after modifier key symbols (e.g. '⇧⌘ і *прокрутка*'). In Ukrainian, "й" expects to flow from a preceding vowel sound while "і" works naturally after a consonant or pause. (If the user doesn't read ⇧⌘ out loud in their mind, it may feel like a pause?) Elsewhere, we're using "й".
    Desired Translation: Use 'прокрутка' over 'прокручування' for 'Scroll'.
        Explanation: Both are valid Ukrainian. Apple uses "прокрутка" rarely, but we prefer it since we care about brevity.
Catalan
    Desired Translation: Use noun + infinitive pattern for drag/scroll (`clic i *arrossegar* %@`, `clic i *desplaçar* %@`, ...)
        Explanation: This is similar to Portuguese, but for different reasons. Turning the phrase into consistent 
            infinitive/imperatives requires adding "fer clic"/"fes clic". For conciseness' sake, we omit fer/fes and turn clic into a noun.
            For the verb parts (drag, scroll), we use infinitives (arrossegar, desplaçar) rather than imperatives (arrossega, desplaça).
            Catalan menus actually use imperatives (Desfes, Copia, Enganxa), but we still use infinitives for the trigger.* instead 
            (Deviating a bit from the suggestion above under `4. Think about the %@ placeholders`) since it feels more appropriate in Catalan 
            for this kind of descriptive label.
            Apple's "Click & drag" → "Fer clic i arrossegar" also uses infinitives for this kind of descriptive label.
            The noun + infinitive mix is slightly unusual grammatically but acceptable for UI brevity.
    Desired Translation: Use "mantén %@" for Hold (without "clicat" or "premut")
        Explanation: The glossary-research agent only found "mantén premut". But this is used for tapping touch screens. For mice, Apple uses "mantén clicat". 
            Sometimes, Apple also uses "mantén" alone.
            Since we strongly value concisenes, we went with "mantén" – this should be clear enough in the context of the app.
                (Context example: "mantén botó central" = "hold middle button" - the meaning is unambiguous in a mouse button trigger list.)
Hebrew
    Desired Translation: Use "ב" (in/with) instead of "על" (on) for the grammatical connector in `trigger.substring.button-name.*` strings.
        → "*בכפתור אמצעי*", "*בכפתור %@*", "*בכפתור ראשי*", "*בכפתור משני*"
            Combined string example: "לחיצה ו*גרירה* *בכפתור אמצעי*" (click and drag with middle button)
        Explanation: "על" (on) doesn't work semantically for actions like drag and scroll — you don't drag "on" a button, you drag "with" the button.
            "ב" expresses the instrumental relationship (using the button) and works naturally for all action types: לחיצה בכפתור (click), גרירה בכפתור (drag), החזקה בכפתור (hold).
            "ב" is also shorter since it's a prefix that attaches to כפתור, rather than a separate word.=
Multiple Languages
    Desired Translation: Grammatical connectors in `trigger.substring.button-name.*` strings.
        Explanation: The `trigger.substring.button-name.*` strings are inserted into the other `trigger.substring.*` strings at the format specifiers (%@). The combined strings needs to feel grammatically sound. In some languages this requires connectors.
        By language:
            French: Use "du" (of the)       
                → "du *bouton central*", "du *bouton %@*", "du *bouton principal*", "du *bouton secondaire*"
                    Combined string example: "clic et *glissement* du *bouton principal*"
                    Reasoning: "du" is shorter than "sur le" while still sounding natural (I hope). "du" is also more semantically sound for some strings ("clic et *glissement* du *bouton principal*" is more reasonable than "clic et *glissement* sur le *bouton principal*")
            Czech: Use genitive case (expresses "of", like French "du")
                → "*středního tlačítka*", "*tlačítka %@*", "*primárního tlačítka*", "*sekundárního tlačítka*"
                    Note: Genitive case endings differ from nominative, so these won't match the group-row headers exactly.
            Russian: Use genitive case (expresses "of", like French "du")
                → "*средней кнопки*", "*кнопки %@*", "*основной кнопки*", "*вспомогательной кнопки*"
                    Note: Genitive case endings differ from nominative, so these won't match the group-row headers exactly.
            Other languages:
                Some other languages like Spanish and Portuguese also use such grammatical connectors, but we prefer to keep things simple and decided we could get away without them. 
                Romanian: For Romanian, we decided to omit the grammatical connectors (genitive) – So `*buton principal*` instead of `*butonului principal*`.
                        Explanation: The combined strings will have slightly inelegant noun+noun juxtaposition (E.g. triplu clic *butonului principal*), but we strongly value conciseness and Apple's Romanian glossary also seems to use the noun+noun juxtaposition without genitive. 
                            (Examples from Apple's glossary:
                                "Double-Click Home Button"  -> "Dublu clic buton principal", 
                                "Mouse drag"                -> "Tragere maus", 
                                "Drag and Drop Modifiers"   -> "Modificatori tragere și eliberare"
                            ).
        Note: We decided English does NOT need "the" and that "Click Middle Button" (instead of "Click the Middle Button") feels like acceptable UI shorthand.
        Note to self: We also added comments about this to 
            trigger.substring.button-name.middle AND 
            trigger.substring.click.1 
            (So I'm not sure explaining it again here is useful.)
