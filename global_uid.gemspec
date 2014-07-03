Gem::Specification.new 'global_uid', '1.4.1' do |s|
  s.summary     = "GUID"
  s.description = "GUIDs for sharded models"
  s.authors     = ["Ben Osheroff"]
  s.email       = 'ben@zendesk.com'
  s.homepage    = 'https://github.com/zendesk/global_uid'
  s.license     = "MIT"

  s.add_dependency('activerecord', '>= 3.2.0', '<5.0')
  s.add_dependency('activesupport')

  s.add_development_dependency('mysql', '2.8.1')
  s.add_development_dependency("appraisal")
  s.add_development_dependency('rake')
  s.add_development_dependency('bundler')
  s.add_development_dependency('shoulda')
  s.add_development_dependency('mocha')
  s.add_development_dependency('test-unit')

  s.files = `git ls-files lib`.split("\n")
end
