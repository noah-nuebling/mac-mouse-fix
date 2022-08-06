#  Notes

## On Code Signing Certificates

Edit: I saved the code signing identity in the Apple Note "noah.n.developer - Apple ID and Code Signing Assets Export (05.08.2022)"
 
*Do not* build this project on other computers (or other user accounts) using the noah.n.developer@gmail.com Apple ID before transferring over the old code signing certificate with date 08.01.2022!

    Otherwise Xcode will create a new certificate for the account and invalidate the old one. When the old one is invalidated users won't be able to open the app and will see scary messages instead.
    If you don't have access to the existing code signing certificate for noah.n.developer@gmail.com, use noah.n.developer.norelease@gmail.com` instead for private development.
    See NotePlan note "MMF - Signing Issues - Jan 2022" for more info

