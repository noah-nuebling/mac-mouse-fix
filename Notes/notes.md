#  Notes

**Note to self** 
*Do not* build this project on other computers (or other user accounts) using the noah.n.developer@gmail.com Apple ID before transferring over the old code signing certificate!
    Otherwise Xcode will create a new certificate for the account and invalidate the old one. When the old one is invalidated users won't be able to open the app and will see scary messages instead.
    If you don't have access to the existing code signing certificate for noah.n.developer@gmail.com, use noah.n.developer.norelease@gmail.com` instead for private development.
    See NotePlan note "MMF - Signing Issues - Jan 2022" for more info

