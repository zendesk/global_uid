require 'rubygems'

require 'jeweler'
Jeweler::Tasks.new do |s|
  s.name        = "global_uid"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ben Osheroff"]
  s.email       = ["ben@zendesk.com"]
  s.homepage    = "http://github.com/zendesk/global_uid"
  s.summary     = "Zendesk GUID"
  s.description = "Zendesk GUID"

  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency("activerecord")
  s.add_dependency("activesupport")
  s.add_dependency("mysql", "2.8.1")

  s.add_development_dependency("rake")
  s.add_development_dependency("jeweler")
  s.add_development_dependency("bundler")
  s.add_development_dependency("shoulda")
  s.add_development_dependency("mocha")

  s.files        = Dir.glob("lib/**/*")
  s.test_files   = Dir.glob("test/**/*")
  s.require_path = 'lib'
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

task :default => :test
