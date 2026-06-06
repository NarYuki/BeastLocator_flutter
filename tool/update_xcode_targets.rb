require "xcodeproj"

project_path = File.expand_path("../ios/Runner.xcodeproj", __dir__)
project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |target| target.name == "Runner" }
raise "Runner target not found" unless runner

def group(project, path)
  parts = path.split("/")
  current = project.main_group
  parts.each do |part|
    current = current.groups.find { |g| g.display_name == part } || current.new_group(part, part)
  end
  current
end

def file_ref(project, group_path, file_path)
  g = group(project, group_path)
  name = File.basename(file_path)
  g.files.find { |f| f.path == name } || g.new_file(name)
end

def ensure_target(project, symbol, name, platform, deployment_target)
  project.targets.find { |target| target.name == name } ||
    project.new_target(symbol, name, platform, deployment_target)
end

def add_source(target, ref)
  target.add_file_references([ref]) unless target.source_build_phase.files_references.include?(ref)
end

def add_resource(target, ref)
  target.resources_build_phase.add_file_reference(ref, true) unless target.resources_build_phase.files_references.include?(ref)
end

def ensure_dependency(host, child)
  return if host.dependencies.any? { |dep| dep.target == child }
  host.add_dependency(child)
end

def ensure_copy_phase(host, name, dst_subfolder_spec, dst_path, product_ref)
  phase = host.copy_files_build_phases.find { |p| p.name == name } || host.new_copy_files_build_phase(name)
  phase.dst_subfolder_spec = dst_subfolder_spec
  phase.dst_path = dst_path
  build_file = phase.files.find { |f| f.file_ref == product_ref } || phase.add_file_reference(product_ref)
  build_file.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }
end

live = ensure_target(project, :app_extension, "BeastLocatorLiveActivity", :ios, "16.1")
live_source = file_ref(project, "BeastLocatorLiveActivity", "BeastLocatorLiveActivity.swift")
live_assets = file_ref(project, "BeastLocatorLiveActivity", "Assets.xcassets")
add_source(live, live_source)
add_resource(live, live_assets)
live.build_configurations.each do |config|
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "moe.n4tsu.beast.LiveActivity"
  config.build_settings["PRODUCT_NAME"] = "$(TARGET_NAME)"
  config.build_settings["INFOPLIST_FILE"] = "BeastLocatorLiveActivity/Info.plist"
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "16.1"
  config.build_settings["MARKETING_VERSION"] = "1.0.0"
  config.build_settings["CURRENT_PROJECT_VERSION"] = "1"
  config.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = ""
end
ensure_dependency(runner, live)
ensure_copy_phase(runner, "Embed App Extensions", "13", "", live.product_reference)

watch = ensure_target(project, :watch2_app, "BeastLocatorWatchApp", :watchos, "10.0")
watch_source = file_ref(project, "BeastLocatorWatchApp", "BeastLocatorWatchApp.swift")
watch_assets = file_ref(project, "BeastLocatorWatchApp", "Assets.xcassets")
add_source(watch, watch_source)
add_resource(watch, watch_assets)
watch.build_configurations.each do |config|
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "moe.n4tsu.beast.watchkitapp"
  config.build_settings["PRODUCT_NAME"] = "BeastLocator"
  config.build_settings["INFOPLIST_FILE"] = "BeastLocatorWatchApp/Info.plist"
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["WATCHOS_DEPLOYMENT_TARGET"] = "10.0"
  config.build_settings["MARKETING_VERSION"] = "1.0.0"
  config.build_settings["CURRENT_PROJECT_VERSION"] = "1"
  config.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
end
ensure_dependency(runner, watch)
ensure_copy_phase(runner, "Embed Watch Content", "16", "$(CONTENTS_FOLDER_PATH)/Watch", watch.product_reference)

project.save
