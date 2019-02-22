require 'bundler/setup'
require 'bundler/gem_tasks'
require 'bump/tasks'
require 'rake/testtask'

task :default => 'test'

Rake::TestTask.new(:test) do |test|
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end
