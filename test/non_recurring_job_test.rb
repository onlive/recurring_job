# Copyright (C) 2014 OL2, Inc. All Rights Reserved.

require 'test_helper'

class NonRecurringJobTest < ActiveSupport::TestCase
  class MyNonRecurringJob < NonRecurringJob
    def perform
      raise "Must have options!" unless options
      logger.debug("Action: #{options[:action]}")
      case options[:action]
        when :error
          raise 'FAILING'
        when :delay
          logger.debug("Sleeping")
          sleep(5)
        else
         logger.debug("Performing a one time task")
      end
    end
  end

  def setup
    Delayed::Job.delete_all
  end

  def test_cant_schedule_job
    # nothing is scheduled when we start
    assert_nil(MyNonRecurringJob.next_scheduled_job)
    assert_raises(RuntimeError){MyNonRecurringJob.schedule_job({interval:0})}
  end


  def test_job_with_no_schedule
    # run MyRecurringJob one time only with no interval set and check that it's not rescheduled
    RecurringJob.logger.debug("test_job_with_no_schedule")
    job = MyNonRecurringJob.queue_once(action: :something, queue:"DifferentName")

    assert_includes(Delayed::Job.all, job)

    # now run the job from the queue
    Delayed::Worker.new.work_off

    # There should be no jobs in the queue (wasn't rescheduled)
    assert_empty(Delayed::Job.all, "Queue should be empty")
  end

  def test_default_queue_once
    # can't queue_once with default_queue as queue
    queue_name = MyNonRecurringJob.default_queue
    assert_raises(RuntimeError) do
      job = MyNonRecurringJob.queue_once(action: :something, queue:queue_name)
    end
  end

end