**Overview**

You are translating strings for **Mac Mouse Fix**, an indie macOS app that enhances mouse functionality.

**Strings we're translating:**

    trial-notif.*
    trial-counter.*
    license-button.*
    license-toast.*
    JJv-GH-7io.placeholderString

    How these strings are used:
        The trial-notif.* and trial-counter.* strings appear on:
            1. The 'trial notification' (which shows up once the trial is over) 
            2. The About tab (only while the trial is active)
            These strings are part of a UI widget that:
                1. Informs the user of the status of their trial (How many of their 'free days' they have used up)
                2. Provides convenient way to open the 'license sheet', where the license can be entered and activated
        The license-button.* and JJv-GH-7io.placeholderString strings appear on the 'license sheet'.
            The 'license sheet' presents a simple interface with 3 elements:
                1. The 'license field' where the user can enter their key
                2. The 'license button' which activates or deactivates the key
                3. A 'Cancel' button which dismisses the sheet (But its label is auto-translated by AppKit, so we don't need to worry about it here.)
        When the user clicks the 'license button' to activate/deactivate their license, a toast notification provides feedback using one of the license-toast.* strings.

**The mfstrings tool**

Use this to inspect and edit strings in the project.

Examples:
    Inspect:
        ./run mfstrings inspect --cols fileid,key,comment,en,LOCALE --sortcol key | grep PATTERN
    Edit:
        ./run mfstrings edit --path 'FILEID/KEY/LOCALE' --state 'translated' --value 'new text'

Tips:
    - Use single quotes for `--value`. Double quotes can corrupt format specifiers.
        - If you need to output literal single quotes, use the standard '\'' trick or $''.
    - Replace `LOCALE` with your target locale, e.g., `de`, `fr`, `zh-Hans`
    - Use `--help` after mfstrings or one of its subcommands (like 'inspect') to learn more.

**Constraints and Guidance**

Quotes
    Guidance: Use the simplest option that feels natural.
    Examples: 
        English -> we use single quotes (') everywhere. 
            Explanation: Feels semantically identical to me and slightly simpler than double quotes ("), so we standardized on that.
        German -> we use single quotes (') everywhere
            Explanation: Feels simpler, still familiar vs the standard „bottom-opening/top-closing“ quotes
                May signal slight unprofessionalism, but I really dislike 'smart substitution' – I think it preserves a convention from hand writing that serves no more purpose, and is harder to work with vs using characters that keyboard can directly output. (Breaks grepping, only works in some text fields).
        French -> we use standard « guillements »
            Explanation: In contrast to German „bottom-opening/top-closing“, these can be typed directly on a (French speaker's) keyboard without smart substitution. They also have a very different shape, so 'simplifying' to single quotes feels less appropriate.
        Traditional Chinese -> We use standard 「corner brackets」
            Explanation: CJK languages rely on IME's anyways so the anti-smart-substitution argument doesn't apply. 「corner brackets」 also have a very different shape (and width), so 'simplifying' to single quotes feels less appropriate.

**Desired translations**

The rest of this document is designed to help you make your own decisions about how to translate into ANY language.
But for some texts, I found it helpful to specify the desired translations directly.

The 'Explanation' sections may help you choose translations for other languages, by using the same guiding principles.

German 
    Desired translation: Use 'kostenloser Tag' for 'free day' (Instead of Testtag)
        Explanation: We're deliberately using 'free' in English over 'trial' or 'test' to imply that the user is using the full version of the app with no feature restrictions.
    Desired translation: Use forward slash for the free-day counter (x/y) just like English
        Explanation: The comment mentions using 'whatever formatting looks natural in your language', and gives the example 'x of y'. 
            While both 'x von y' and 'x/y' feel natural in German, 'x/y' is shorter and more scannable, so we prefer it.
    Desired translation: Use 'Fehlermeldung:' for 'It says:' in license-toast.gumroad-error
        Explanation: 'It says:' doesn't exactly translate to German. Approximations feel a little awkward. 'Fehlermeldung:' works well.
    Desired translation: Use 'Gib deinen Lizenzschlüssel ein' for 'Enter your license key'.
        Explanation: German mostly avoids imperative in UI text (Kopieren, Einfügen, etc...) but here, imperative feels appropriate. (Perhaps because we're directly prompting the user to do something, not just describing an available command for the computer)
        (Counterargument?: Safari uses 'Suchbegriff oder Websitenamen eingeben' as the placeholder in the address bar, not 'Gib einen Suchbegriff oder Websitenamen ein' – this is a similar context, but for some reason, imperative still feels better for the license field)
    Desired translation: 'Deine App **ist bereits** mit diesem Schlüssel **lizenziert**' for 'Your app is **already licensed** with this key'. (license-toast.already-active)
        Explanation: We accept splitting the emphasized substring into two, to keep the most natural grammatical structure for German.
        On emphasis: The emphasis in these kinds of strings exists for scannability. The idea is that, when someone only reads the emphasized words, they already get the gist.
            In this case, '**ist bereits** ... **lizensiert**' (as feedback to clicking an 'activate license' button) serves a a decent 'gist', equivalent to the original emphasized substring '**already licensed**'.
            (I'm not sure this is the best design, but that's the intention behind the emphasis in the English strings – let's roll with it for now)
    Desired translation: Use 'deine App' for 'your app' in license-toast.already-active
        Explanation: Using just 'die app' makes the message ambiguous – It could imply the activation failed because the license has been used before
    Desired translation: Use 'momentan **in deinem Land kostenlos**' for 'currently **free in your country**' (In license-toast.free-country)
        Explanation: We want to make the emphasized bits form a 'gist' that contains ~the same information in German as in the English original. (See 'On emphasis:' above.)
    Desired translation: Use 'Stell sicher, dass du ...' for 'Make sure you ...' in license-toast.unknown-key
        Explanation: This is a general tip about a common mistake. We're not sure this is the reason for the error.
            Dropping the 'make sure' and using bare imperative could make it sound like we're diagnosing a specific mistake that the user made with certainty, which could be confusing or frustrating.

French
    Desired translation: Use `m'excuser` (personal voice) in license-toast.activation-overload (instead of corporate 'we' voice `nous excuser` )
        Explanation: These texts are messages by me (the indie developer) to the user. There's no corporation or collective behind the app. 
    Desired translation: Use 'une licence' instead of 'la license' in trial-notif.activate-license-button
        Explanation: This string is the label for a button that appears on the 'About tab' and on the 'trial notification'. It takes you to the 'license sheet' where you can enter and activate (or deactivate) your license key. But before you open the license sheet, there's no specific license in context to refer to, so 'la license' would feel wrong. (English 'Activate License' circumvents this issue by not using 'a'/'the' at all)
    Desired translation: Use 'jours offerts' for 'free days'
        Explanation: It seems about as good as 'jours gratuits', but 'jours offerts' is what a previous human translator chose, so we defer to that.

Brazilian Portuguese
    Desired translation: Use 'servidor de licenças' for 'license server'
        Explanation: Using plural for licenças sounds more natural
    Desired translation: Use 'Ocorreu um **erro com o servidor de licenças**' for 'An **error with the licensing server** occurred'
        Explanation: Verb-first sounds more natural

Spanish
    Desired translation: Use '¡Tu licencia ha sido **activada**! 🎉' for 'Your license has been **activated**! 🎉'
        Explanation: Use exclamation marks over period to match the original tone.
    Desired translation: Use 'ordenador' for 'computer' (over 'computadora')
        Explanation: The Spanish (es) locale should use European Spanish conventions over Latin American Spanish ones.
    Desired translation: Use `Llevas usando Mac Mouse Fix` for `You've been using Mac Mouse Fix` (instead of `Has estado usando Mac Mouse Fix`)
        Explanation: Sounds more natural than the more literal translation.
    Desired translation: Use 'Dice:' for 'It says:'.
        Explanation: 'Dice:' is short and simple. Unlike German, Spanish can translate 'It says:' naturally.
    Desired translation: Use '**ya está licenciada**' for '**already licensed**' in license-toast.already-active
        Explanation: The emphasis contains the same words as in English making it form an equivalent 'gist'. (See 'On emphasis:' above)

Czech
    Desired translation: Use informal 'ty' (over formal 'vy')
        Explanation: 'ty' feels appropriate for an indie app. (This differs by language, e.g. in French we're using 'vous')

Turkish
    Desired translation: Use formal address 'siz' (over informal 'sen')
        Explanation: Both seem good for Turkish. But this is what a previous human translator chose, so we defer to that.
    Desired translation: Use 'keyif almak' for 'enjoying' in trial-notif.body (over 'beğenmek')
        Explanation: Claude says 'Keyif almak' is warmer than 'beğenmek'. This is what a previous human translator chose, so we defer to that.

Korean:
    Desired translation: Include topic marker '이 앱은' (this app) in license-toast.already-active
        Explanation: Without something like 'this' or 'your', the message is ambiguous – It could imply the activation failed because the license has been used before
            (Mirrors German guidance about using 'deine App' over 'die App' here)
    Desired translation: Use '버그 제보' for 'Bug Report'
        Explanation: Short, natural, what human translator chose

Simplified Chinese:
    Desired translation: Use '你的应用**已使用此密钥激活**' for 'Your app is **already licensed** with this key' (license-toast.already-active)
        Explanation: 
            We don't like including extra information in the emphasis (使用此密钥 = "with this key") since that may lower scannability,
            but splitting to '你的应用**已**使用此密钥**激活**' feels grammatically awkward because 已 naturally binds to the verb immediately following it (使用), not to 激活 at the end.
            (I'm not sure this is the right tradeoff, but let's roll with it for now.)

European Portuguese (pt-PT)
    Desired translation: Use informal 'tu' address
        Explanation: Seems appropriate for an indie app with a more casual voice
    Desired translation: Avoid mesoclisis
        Explanation: Mesoclisis sounds very formal/literary, clashing with informal 'tu' address
    Desired translation: Use 'está' (not 'é') in '... Mac Mouse Fix está atualmente **gratuito no teu país**' (license-toast.free-country)
        Explanation: atualmente implies a temporary condition clashing with 'é'
    Desired translation: Use sentence case (not title case)
        Explanation: English UI often uses title case, but Portuguese UI uses sentence case.

Dutch
    Desired translation: Don't put links on separated verb-parts (e.g. 'Neem gewoon [contact op]()' for 'Just [reach out]()').
        Explanation: It's a bit awkward, since the link-text doesn't form a self-contained phrase.
        Tip: You can always use '[hier]()' as the link text to sidestep the problem.

Swedish
    Desired translation: Use compounds for 'free day' ('Gratisdag' / 'Gratisdagarna') in trial-counter.*
        Explanation: 'Gratis dag' / 'Gratis dagarna' as separate words feels unnatural in this context.
    Desired translation: Don't use 'Det står:' for 'It says:' in license-toast.gumroad-error
        Explanation: 'Det står:' implies something physically written on a surface, which feels a bit off for a server error.
            (Sidenote: We avoid German equivalent 'Da steht:' for similar reasons)

Arabic
    Desired translation: Use 'يومًا' (singular accusative) for 'days' in trial-notif.body
        Explanation: There are 11+ trial days (30 at the time of writing). Therefore, singular accusative is the correct form.

Hebrew
    Desired translation: Don't use 'ביטול' for 'deactivate' in license-toast.deactivate and license-button.deactivate
        Explanation: This option simply disassociates the license from the app, but does not permanently annul it. 'ביטול' implies permanence.
    Desired translation: Emphasize 'לא ניתן היה להפעיל' (could not be activated) in license-toast.free-country
        Explanation: Emphasizing '**לא ניתן היה להפעיל**' matches the English gist '**could not be activated**'

Greek
    Desired translation: Use sentence case (not title case)
        Explanation: Greek UI text uses sentence case - only the first word is capitalized. E.g. 'Ενεργοποίηση άδειας' not 'Ενεργοποίηση Άδειας'.