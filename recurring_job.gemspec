# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'recurring_job/version'

Gem::Specification.new do |spec|
  spec.name          = "recurring_job"
  spec.version       = RecurringJob::VERSION
  spec.authors       = ["Ruth Helfinstein", "Noah Gibbs"]
  spec.email         = ["ruth.helfinstein@onlive.com", "noah@onlive.com"]
  spec.summary       = %q{Schedule DelayedJob tasks to repeat after a given interval.}
  spec.description   = <<DESC
Recurring_job creates a framework for creating custom DelayedJob jobs
that are automatically rescheduled to run again at a given interval.
DESC
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'activesupport', ['>= 3.0', '< 5.0']
  spec.add_runtime_dependency 'activerecord', '>= 3.0', '< 5.0'
  spec.add_runtime_dependency 'delayed_job_active_record', '~> 4.0'

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.4"
  spec.add_development_dependency "rr", '~> 1.1'
  spec.add_dependency 'sqlite3', '~> 1'

end
