require 'bundler/setup'
require 'bundler/gem_tasks'
require 'bump/tasks'
require 'rake/testtask'

task :default => ['test', 'performance_test']

Rake::TestTask.new(:test) do |test|
  test.pattern = 'test/lib/*_test.rb'
  test.verbose = true
end

Rake::TestTask.new(:performance_test) do |test|
  test.pattern = 'test/performance/*_test.rb'
  test.verbose = true
end
