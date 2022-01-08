#  Notes

**Note to self** 
*Do not* build this project on other computers (or other user accounts) using the noah.n.developer@gmail.com Apple ID before transferring over the old code signing certificate!
    (It is untested whether transferring the old certificate actually fixes this, but I suspect it to)
    Otherwise Xcode will create a new certificate and invalidate the old one. When the old one is invalidated users won't be able to open the app and will see scary messages instead.
    See NotePlan note "MMF - Signing Issues - Jan 2022" for more info

