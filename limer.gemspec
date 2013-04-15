# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "limer/version"

Gem::Specification.new do |s|
  s.name        = "limer"
  s.version     = Limer::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Orgil Urtnasan"]
  s.email       = ["orgil@limesoft.mn"]
  s.homepage    = "http://limesoft.com"
  s.summary     = 'Command line tools for tasks at Limesoft.'
  s.description = 'COmmand line tools for tasks at Limesoft.'

  s.rubyforge_project = "limer"

  s.add_dependency("highline", "~> 1.6.17")
  s.add_dependency("pivotal-tracker","~> 0.5.10")

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
