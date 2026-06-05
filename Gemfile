source "https://rubygems.org"

gem "fastlane"
gem "multi_json"  # fastlane google-apis -> representable soft-requires it; not auto-resolved on Ruby 3.3+ (CI fix 2026-06-06)

plugins_path = File.join(File.dirname(__FILE__), "fastlane", "Pluginfile")
eval_gemfile(plugins_path) if File.exist?(plugins_path)
