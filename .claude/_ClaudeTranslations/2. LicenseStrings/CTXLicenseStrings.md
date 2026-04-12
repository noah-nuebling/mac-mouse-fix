**Overview**

You are translating strings for **Mac Mouse Fix**, an indie macOS app that enhances mouse functionality.

**Strings we're translating:**

    trial-notif.*
    trial-counter.*
    license-button.*
    license-toast.*
    JJv-GH-7io.placeholderString

**The mfstrings tool**

Use this to inspect and edit strings in the project.

Examples:
    Inspect:
        ./run mfstrings inspect --cols fileid,key,comment,en,LOCALE --sortcol key | grep PATTERN
    Edit:
        ./run mfstrings edit --path 'FILEID/KEY/LOCALE' --state 'translated' --value 'new text'

Tips:
    - Use single quotes for `--value`. Double quotes can corrupt format specifiers.
        - If you need to output literal single quotes, use the standard '\'' trick.
    - Replace `LOCALE` with your target locale, e.g., `de`, `fr`, `zh-Hans`
    - Use `--help` after mfstrings or one of its subcommands (like 'inspect') to learn more.

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
    license-toast.already-active
        Desired translation: 'Deine App **ist bereits** mit diesem Schlüssel **lizenziert**' for 'Your app is **already licensed** with this key'.
            Explanation: We accept splitting the emphasized substring into two, to keep the most natural grammatical structure for German.
            Background: The emphasis in these kinds of strings exists for scannability. The idea is that, when someone only reads the emphasized words, they already get the gist.
                In this case, '**ist bereits** ... **lizensiert**' (as feedback to clicking an 'activate license' button) serves a a decent 'gist', equivalent to the original emphasized substring '**already licensed**'.
                (I'm not sure this is the best design, but that's the intention behind the English strings – let's roll with it for now)
        Desired translation: Use 'deine App' for 'your app'
            Explanation: Using just 'die app' makes the message ambiguous – It could imply the activation failed because the license has been used before
