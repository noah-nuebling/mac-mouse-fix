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
        - If you need to output literal single quotes, use the standard '\'' trick.
    - Replace `LOCALE` with your target locale, e.g., `de`, `fr`, `zh-Hans`
    - Use `--help` after mfstrings or one of its subcommands (like 'inspect') to learn more.

**Constraints and Guidance**

Quotes
    Guidance:
        - Use what feels most appropriate for your specific context/language.
        - If the decision seems arbitrary – tend towards the simplest option, and keep it consistent inside the language. (Like we're consistently using single quotes over double quotes in English - see below)
    Explanation / Background:
        In English, we use single quotes (') everywhere. 
            Before, I randomly mixed single quotes and double quotes, because my brain doesn't really differentiate between them. Eventually, I standardized on single quotes since they are a little simpler.
        In German, we don't like to use special 'smart quotes' characters, since normal ascii quotes work fine and are easier to work with – I also find it 'simpler' or 'more honest' in a digital world to just use characters that can be directly typed on a (native-speaker's) keyboard, without smart-substitution. People will also be guaranteed to be familiar with the characters that their keyboard directly outputs – even if it doesn't perfectly resemble the conventions of hand-written text.
            (Might have to revisit this decisions for languages that rely on IMEs like Japanese)

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