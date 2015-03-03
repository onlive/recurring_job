# Copyright (C) 2015 OL2, Inc. See LICENSE.txt for details.

require "recurring_job"

# because RecurringJob is a class that has a superclass,
# this doesn't work without putting the superclass, which is weird
# class RecurringJob
#   VERSION = "0.0.1"
# end

RecurringJob::VERSION = "0.0.3"
