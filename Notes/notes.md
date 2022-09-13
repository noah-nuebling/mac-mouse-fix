#  Notes

## On changing Bundle ID to com.nuebling.mac-mouse-fixxx

On 13.09.2020, right after publishing MMF 3.0.0 Beta 1, I started seeing weird errors saying "Change your bundle identifier to a unique string to try again". I thought I might be able to fix this by enrolling in the Developer Program, so I did, but it didn't help. Tried other solutions from SO but nothing helped. The only fix was to change the Bundle ID. So I changed it from com.nuebling.mac-mouse-fix -> com.nuebling.mac-mouse-fixxx. I also changed the Helper and Accomplice Bundle IDs accordingly.

Also see NotePlan note [[MMF - Scraps - Distribution through Developer Program]]

## On Code Signing Certificates

Edit: We enrolled noah.n.developer@gmail.com in the Apple Developer Program on 13.09.2022 which might change how we need to handle all of this!

Edit: I saved the code signing identity in the Apple Note "noah.n.developer - Apple ID and Code Signing Assets Export (05.08.2022)"
 
*Do not* build this project on other computers (or other user accounts) using the noah.n.developer@gmail.com Apple ID before transferring over the old code signing certificate with date 08.01.2022!

    Otherwise Xcode will create a new certificate for the account and invalidate the old one. When the old one is invalidated users won't be able to open the app and will see scary messages instead.
    If you don't have access to the existing code signing certificate for noah.n.developer@gmail.com, use noah.n.developer.norelease@gmail.com` instead for private development.
    See NotePlan note "MMF - Signing Issues - Jan 2022" for more info

