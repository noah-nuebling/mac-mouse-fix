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
    Desired translation: 'kostenloser Tag' for 'free day' (Instead of 'Testtag')
        Explanation: We're deliberately using 'free' in English over 'trial' or 'test' to imply that the user is using the full version of the app with no feature restrictions.
    Desired translation: 'Gib deinen Lizenzschlüssel ein' for 'Enter Your License Key' (Instead of 'Lizenzschlüssel eingeben')
        Explanation: This is a placeholder text in a text field – it's specifically prompting the user to do something, so imperative in German seems most appropriate (Even though German often avoids imperative in UI, e.g. for action-labels like 'Copy' and 'Paste', where 'Kopiere', 'Füge ein' would sound awkward.)