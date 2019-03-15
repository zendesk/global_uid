Gem::Specification.new 'global_uid', '3.7.0' do |s|
  s.summary     = "GUID"
  s.description = "GUIDs for sharded models"
  s.authors     = ["Benjamin Quorning", "Gabe Martin-Dempesy", "Pierre Schambacher", "Ben Osheroff"]
  s.email       = ["bquorning@zendesk.com", "gabe@zendesk.com", "pschambacher@zendesk.com"]
  s.homepage    = 'https://github.com/zendesk/global_uid'
  s.license     = "MIT"

  s.required_ruby_version = "~> 2.3"

  s.add_dependency('activerecord', '>= 4.2.0', '< 6.0')
  s.add_dependency('activesupport')
  s.add_dependency('mysql2')

  s.add_development_dependency('rake')
  s.add_development_dependency('bundler')
  s.add_development_dependency('minitest')
  s.add_development_dependency('minitest-rg')
  s.add_development_dependency('mocha')
  s.add_development_dependency('bump')
  s.add_development_dependency('phenix')

  s.files = Dir.glob('lib/**/*')
end
