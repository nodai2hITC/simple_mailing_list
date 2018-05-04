
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "simple_mailing_list/version"

Gem::Specification.new do |spec|
  spec.name          = "simple_mailing_list"
  spec.version       = SimpleMailingList::VERSION
  spec.authors       = ["nodai2hITC"]
  spec.email         = ["nodai2h.itc@gmail.com"]

  spec.summary       = %q{Simple Mailing List System.}
  spec.description   = %q{This is a simple mailing list system.}
  spec.homepage      = "https://github.com/nodai2hITC/simple_mailing_list"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_dependency "mail"
  spec.add_dependency "activerecord"
  spec.add_dependency "liquid"
  spec.add_dependency "daemons"
  spec.add_dependency "thor"
  spec.add_dependency "sqlite3"
end
