#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'cedularecorder.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main group
main_group = project.main_group['cedularecorder']

# Create or find the Systems group
systems_group = main_group['Systems'] || main_group.new_group('Systems')

# Add Swift files from Systems directory
Dir.glob('cedularecorder/Systems/*.swift').each do |file_path|
  file_name = File.basename(file_path)
  
  # Check if file already exists in the group
  unless systems_group.files.any? { |f| f.path == file_name }
    file_ref = systems_group.new_file(file_path)
    
    # Add to target
    target = project.targets.first
    target.add_file_references([file_ref])
    
    puts "Added #{file_name} to Xcode project"
  end
end

# Save the project
project.save

puts "Xcode project updated successfully!"