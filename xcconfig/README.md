
- ! If we want to move or refactor Base.xcconfig, we need to reflect that in generate_appcasts.py, but also still use the old path for older repo version. So it's better to not refactor it at all if possible.
- We created these xcconfig files to give our generate_appcasts.py script a chance to read the minimum compatible macOS version.
    - When you set env variables from the project editor, those are deeply buries withing the project.pbxproj file, and completely impractical to access for an external script. (External -> Not executed by Xcode as part of the build process)
    - The generate_appcasts.py script will go through all releases, and look at their related commits. Within those, it'll look into [ProjectRoot]/xcconfig/Base.xcconfig and search for the value to MACOSX_DEPLOYMENT_TARGET in there.
        - So if we refactor Base.xcconfig, we need to adjust the generate_appcasts.py script, too

