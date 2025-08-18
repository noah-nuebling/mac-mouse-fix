# Enabling Mac Mouse Fix

If you ran into a problem with enabling Mac Mouse Fix, this guide will help you solve it.

> [!NOTE]
> **Don't read this guide if you're on macOS 15 Sequoia or above, or if you're on macOS 12 Monterey or below**
> The issues and solutions steps discussed in this guide only apply to macOS 13 Ventura and macOS 14 Sonoma. \
> If you're on another macOS version, please leave a comment below, so I can help you out and update this guide. Thanks!

## Why doesn't enabling Mac Mouse Fix work?

With macOS 13 Ventura, Apple introduced a new way for apps to run in the background called 'SMAppService'. Issues with this new system can cause problems with enabling Mac Mouse Fix. Especially if you have more than one copy of Mac Mouse Fix installed.

Update: Under macOS 15 Sequoia, Apple seems to have fixed these issues! If you're still experiencing issues with enabling Mac Mouse Fix, please leave a comment below so I can help you out and update this guide. Thank you.

**Additional Info**

Overall, I think the the new SMAppService system is a great improvement. It is much easier to use for developers and it gives users a way to see and control which apps run in the background at [System Settings > General > Login Items](https://noah-nuebling.github.io/redirection-service/?target=macos-settings-loginitems).

However, the new SMAppService system unfortunately has some bugs at the moment. Under certain circumstances, such as when you have two different copies of Mac Mouse Fix on your computer, the SMAppService system can get really confused. And then enabling Mac Mouse Fix won't work anymore.

Mac Mouse Fix 3 and later try to automatically detect these issues and provide solution steps right in the app. However, sometimes this is not possible. For those cases, or if you're using Mac Mouse Fix 2, this guide provides steps to solve the issue.

## The Solution

Below, you will find two solutions. You might have to use one or both of the solutions to solve the issue. 

The 1. Solution is simpler and should work in most circumstances. So I recommend starting with that. However, the 1. Solution will enable all "Allow in the Background" items under [System Settings > General > Login Items](https://noah-nuebling.github.io/redirection-service/?target=macos-settings-loginitems). If you'd like to avoid that, you might want to start with the 2. Solution.

<!-- 

Message when running resetbtm:

sfltool would like to reset Login Items.
This will enable all "Allow in the Background" items in Login Items
Settings. Reboot your Mac after running this command.
Touch ID or enter your password
-->

### 1. Solution: Reset the Background-App Database

This solution resets a specific part of your computer's system that manages background apps. For most users this will fix the issue with Mac Mouse Fix.

<!--
The Background-App Database of macOS can easily become corrupted, leading to problems such as not being able to enable Mac Mouse Fix. But luckily, there's an easy way to repair the database:
-->

1. Open the Terminal app. 
3. Enter the following command and press Return:
    ```
    sudo sfltool resetbtm
    ``` 
4. When prompted, enter your password.
5. Restart your computer.
6. Try enabling Mac Mouse Fix again.

**Additional Info**

- In case this approach doesn't work, try the **2. Solution**.
- The `sfltool resetbtm` command will enable all "Allow in the Background" items under [System Settings > General > Login Items](https://noah-nuebling.github.io/redirection-service/?target=macos-settings-loginitems). If you'd like to avoid that, you might want to try the **2. Solution** first.
- Apple recommends using the `sfltool resetbtm` command in this [support document](https://support.apple.com/guide/deployment/depdca572563/web), so you can be sure it is safe to use. 

### 2. Solution: Remove Duplicate Copies of Mac Mouse Fix

macOS might be trying to enable a different copy of Mac Mouse Fix than the one you intend to use. To fix this issue, you can delete all duplicate copies of Mac Mouse Fix and restart your computer:

1. Find duplicate copies of Mac Mouse Fix.
    - You can search for "Mac Mouse Fix" using Spotlight or use the Finder to find duplicate copies of Mac Mouse Fix.
    - To find the copy of Mac Mouse Fix that macOS is attempting to enable (and which might be causing these issues), enter the following command in the Terminal app and press Return:
    ```
    sudo sfltool dumpbtm | perl -ne 'print if /Mac%20Mouse%20Fix(?!%20Helper)[^\/]*\.app/' | sed 's/URL: //' | xargs open -R
    ```
    - This command should open a Finder window showing the copy of Mac Mouse Fix that macOS is trying to enable. If this command doesn't reveal anything in the Finder, you might have to restart your computer first for the command to work. <!-- This can happen if you've moved the duplicate copy of Mac Mouse Fix since you last restarted your computer. -->
3. Move any duplicate copies of Mac Mouse Fix which you found to the Trash.
4. Empty the Trash.
5. Restart your computer.
6. Try to enable Mac Mouse Fix again.

**Additional Info**

- In case this approach doesn't work, try the **1. Solution** instead.
<!-- - Mac Mouse Fix 3 and later try to automatically detect if there is a duplicate copy on your computer which prevents enabling. In that case, Mac Mouse Fix will show you solution steps right in the app. However, in case the automatic detection fails or in case you're using Mac Mouse Fix 2 then the 2. Solution might help you. -->

---

I hope this helps! If you have any further questions or suggestions, let me know in a comment below.

*This guide was written with the help of ChatGPT.*
