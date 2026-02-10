#!/usr/bin/env ruby
# Adds RunnerUITests (UI Testing Bundle) target to the macOS Xcode project.
# Used for Patrol E2E integration tests.

# Discover CocoaPods gem directory dynamically (survives version upgrades).
pods_prefix = `brew --prefix cocoapods 2>/dev/null`.strip
if pods_prefix.empty? || !File.directory?(pods_prefix)
  abort 'CocoaPods not found via Homebrew. Install with: brew install cocoapods'
end
gems_dir = File.join(pods_prefix, 'libexec', 'gems')
Dir.glob(File.join(gems_dir, '*/lib')).each { |p| $LOAD_PATH.unshift(p) }
require 'xcodeproj'

project_path = File.join(__dir__, '..', 'macos', 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

# Check if target already exists
if project.targets.any? { |t| t.name == 'RunnerUITests' }
  puts 'RunnerUITests target already exists, skipping.'
  exit 0
end

# Find the Runner target (test host)
runner_target = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless runner_target

# Create UI Testing Bundle target
ui_test_target = project.new_target(
  :ui_test_bundle,
  'RunnerUITests',
  :osx
)

# Add dependency on Runner
ui_test_target.add_dependency(runner_target)

# Add source file reference
group = project.main_group.new_group('RunnerUITests', 'RunnerUITests')
file_ref = group.new_file('RunnerUITests.m')

# Add source file to build phase
ui_test_target.source_build_phase.add_file_reference(file_ref)

# Configure build settings for all configurations
# UI Testing Bundles use USES_XCTRUNNER (set automatically), NOT TEST_HOST.
ui_test_target.build_configurations.each do |config|
  config.build_settings.delete('BUNDLE_LOADER')
  config.build_settings.delete('TEST_HOST')
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'ai.soliplex.client.RunnerUITests'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.15'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['TEST_TARGET_NAME'] = 'Runner'
  # UI test runner needs pod framework dirs on rpath for dynamic framework loading
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = [
    '$(inherited)',
    '@executable_path/../Frameworks',
    '@loader_path/../Frameworks',
    '$(FRAMEWORK_SEARCH_PATHS)',
  ]
end

# Set target attributes (TestTargetID links to Runner)
attributes = project.root_object.attributes['TargetAttributes'] || {}
attributes[ui_test_target.uuid] = {
  'CreatedOnToolsVersion' => '14.0',
  'TestTargetID' => runner_target.uuid,
}
project.root_object.attributes['TargetAttributes'] = attributes

project.save
puts "RunnerUITests target added successfully."
