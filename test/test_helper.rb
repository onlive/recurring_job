# Copyright (C) 2013-2014 OL2, Inc. See LICENSE.txt for details.

# Test local copy first
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "rr"
require 'active_support/dependencies'
require 'active_record'
require 'logger'

require "support/db"
require "recurring_job"
require 'minitest/autorun'

require 'tempfile'

if !Dir.exists?('tmp')
  Dir.mkdir('tmp')
end
RecurringJob.logger = Logger.new('tmp/rj_test.log')

ENV['RAILS_ENV'] = 'test'


# Trigger AR to initialize
# #ActiveRecord::Base # rubocop:disable Void
#
# # Add this directory so the ActiveSupport autoloading works
# ActiveSupport::Dependencies.autoload_paths << File.dirname(__FILE__)
ActiveSupport::TestCase.test_order = :random
#
# # set up underlying db
ActiveRecord::Base.logger = RecurringJob.logger
# ActiveRecord::Migration.verbose = false

ActiveSupport::LogSubscriber.colorize_logging = false



