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
    - Replace `LOCALE` with your target locale, e.g., `de`, `fr`, `zh-Hans`
    - Use `--help` after mfstrings or one of its subcommands to learn more.

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
    Desired translation: Use 'Fehlermeldung' for 'It says' in license-toast.gumroad-error
        Explanation: 'It says:' doesn't exactly translate to German. Approximations feel a little awkward.
    Desired translation: Use 'Gib deinen Lizenzschlüssel ein' for 'Enter your license key'.
        Explanation: German mostly avoids imperative in UI text (Kopieren, Einfügen, etc...) but here, imperative feels appropriate. (Perhaps because we're directly prompting the user to do something, not just describing an available command for the computer)