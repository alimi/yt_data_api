# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "yt_data_api/version"

Gem::Specification.new do |s|
  s.name        = "yt_data_api"
  s.version     = YtDataApi::VERSION
  s.authors     = ["Ali Ibrahim"]
  s.email       = ["aibrahim2k2@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{TODO: Write a gem summary}
  s.description = %q{TODO: Write a gem description}

  s.rubyforge_project = "yt_data_api"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'libxml-ruby', '~>1.1.3'

  s.add_development_dependency 'rspec', '~>2.4.0'
end
