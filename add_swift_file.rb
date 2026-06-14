require 'xcodeproj'
project_path = 'Mouse Fix.xcodeproj'
project = Xcodeproj::Project.open(project_path)

helper_target = project.targets.find { |t| t.name == 'Mac Mouse Fix Helper' }

# Find the group
group = project.main_group.find_subpath(File.join('Helper', 'Core', 'Buttons'), true)

# Create file reference
file_ref = group.new_file('LogitechActivator.swift')

# Add to target compile sources
helper_target.add_file_references([file_ref])

# Remove old files
old_m = group.files.find { |f| f.path == 'LogitechCIDActivator.m' }
old_h = group.files.find { |f| f.path == 'LogitechCIDActivator.h' }

if old_m
  helper_target.source_build_phase.remove_file_reference(old_m)
  old_m.remove_from_project
end

if old_h
  old_h.remove_from_project
end

project.save
