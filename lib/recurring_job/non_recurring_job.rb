# Copyright (C) 2014 OL2, Inc. All Rights Reserved.

class NonRecurringJob < RecurringJob
  # for jobs we only want to run once, but we still want options and queue to be set.
  # uses queue_once and default_queue from underlying RecurringJob but stubs out the recurring parts

  def self.schedule_job(options = {}, this_job=nil)
    raise "schedule_job is not valid for #{default_queue} - can only run once at a time."
  end

  def self.unschedule_job
    raise "unschedule_job not valid for #{default_queue} - can only run once at a time"
  end

  # uses same queue_once and default_queue as recurring job

  def after(job)
    # NEVER reschedule.
  end

end
