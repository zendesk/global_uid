Gem::Specification.new do |s|
  s.name        = "global_uid"
  s.version     = "1.0.0"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ben Osheroff"]
  s.email       = ["ben@zendesk.com"]
  s.homepage    = "http://github.com/zendesk/global_uid"
  s.summary     = "Zendesk GUID"
  s.description = "Zendesk GUID"

  s.required_rubygems_version = ">= 1.3.6"

  is_1_8 = Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new("1.9")

  s.add_dependency("activerecord", "~>2.3.10")
  s.add_dependency("activesupport", "~>2.3.10")
  s.add_dependency("SystemTimer", "1.2") if is_1_8
  s.add_dependency("mysql", "2.8.1")

  s.add_development_dependency("rake")
  s.add_development_dependency("bundler")
  s.add_development_dependency("shoulda")
  s.add_development_dependency("mocha")
  s.add_development_dependency("ruby-debug") if is_1_8

  s.files        = Dir.glob("lib/**/*")
  s.test_files   = Dir.glob("test/**/*")
  s.require_path = 'lib'
end
