#  Notes

## On Code Signing Certificates

Edit: I saved the code signing identity in the Apple Note "noah.n.developer - Apple ID and Code Signing Assets Export (05.08.2022)"
 
*Do not* build this project on other computers (or other user accounts) using the noah.n.developer@gmail.com Apple ID before transferring over the old code signing certificate!
    Otherwise Xcode will create a new certificate and invalidate the old one. When the old one is invalidated users won't be able to open the app and will see scary messages instead.
    
Also see: 
- NotePlan note "MMF - Signing Issues - Jan 2022"
