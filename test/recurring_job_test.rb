# Copyright (C) 2014-2015 OL2, Inc. See LICENSE.txt for details.

require 'test_helper'

class RecurringJobTest < ActiveSupport::TestCase
  @@last_job_id =  nil

  class MyRecurringJob < RecurringJob
    def perform
      raise "Must have options!" unless options
      case options[:action]
        when :error
          raise 'FAILING'
        when :test_id
          logger.debug("Job id is #{options[:delayed_job_id]}")
          RecurringJobTest.last_job_id = options[:delayed_job_id]
        else
         logger.debug("Performing")
      end
    end
  end

  def self.last_job_id=(value)
    @@last_job_id = value
  end

  def setup
    RecurringJob.logger.debug("------------------------------------")
    Delayed::Job.delete_all
  end

  def test_schedule_job
    # nothing is scheduled when we start
    assert_nil(MyRecurringJob.next_scheduled_job)
    # schedule a job which will run immediately and reschedule itself
    # (since not running automatically this will work)
    job = MyRecurringJob.schedule_job({interval:1, action: :perform, first_start_time: Time.now})
    # now this job is scheduled
    assert_equal(job, MyRecurringJob.next_scheduled_job)
    assert_equal(RecurringJob.all, [job])
    # now run the job from the queue
    Delayed::Worker.new.work_off

   # should have added a new job that's different from this one
    job2 = MyRecurringJob.next_scheduled_job
    assert(job2)
    refute_equal(job2, job)

    # if we try to schedule a new one now it should be the same one
    job3 = MyRecurringJob.schedule_job({interval:1, first_start_time: Time.now})
    assert_equal(job2, job3)
  end

  def test_failed_job
    Delayed::Worker.max_attempts = 3 # delete after third failed attempt

    worker = Delayed::Worker.new

    job = MyRecurringJob.schedule_job({interval:1, action: :error})

    # make sure the jobs will run now
    RecurringJob.all.each do |j|
      j.run_at = Time.now
      j.save!
    end
    # run job, will fail
    worker.work_off
    RecurringJob.all.each do |j|
      j.run_at = Time.now
      j.save!
    end

    # there should now be two jobs in the queue
    # since it adds the next job even if there's an error
    assert_equal(2,RecurringJob.all.size, "Should be the new job in the queue")
    jobs = RecurringJob.all
    # they should both run this time and both get errors
    worker.work_off

    RecurringJob.all.each do |j|
      j.run_at = Time.now
      j.save!
    end

    assert_equal(jobs, RecurringJob.all)
    # There should still only be the same two jobs in the queue.
    assert_equal(2,RecurringJob.all.size)

    worker.work_off
    # it's been 3 attempts so original job should be deleted

    RecurringJob.all.each do |j|
      j.run_at = Time.now
      j.save!
    end

    refute_includes(RecurringJob.all, job)

    # The second job will fail a third time and get deleted, but make sure it puts a new job in the
    # queue before it does (to show we will always have at least one job in the queue)
    worker.work_off

    refute_empty(RecurringJob.all)

  end

  def test_uses_different_queues
    job = MyRecurringJob.schedule_job({interval:1, queue:'queue1'})
    job2 = MyRecurringJob.schedule_job({interval:1})
    refute_equal(job, job2)
    assert_equal(job, MyRecurringJob.next_scheduled_job(nil, 'queue1'))
    assert_equal(job2, MyRecurringJob.next_scheduled_job(nil))
  end

  def test_first_start_time
    first_start_time = Date.today.midnight
    job = MyRecurringJob.schedule_job({interval:1, first_start_time:first_start_time})
    assert_equal(first_start_time, job.run_at)
  end

  def test_job_with_no_schedule
    # run MyRecurringJob one time only with no interval set and check that it's not rescheduled
    job = MyRecurringJob.queue_once(action: :something)

    assert_equal(Delayed::Job.all, [job])
    # now run the job from the queue
    Delayed::Worker.new.work_off

    # There should be no jobs in the queue (wasn't rescheduled)
    assert_empty(Delayed::Job.all, "Queue should be empty")
  end

  def test_get_and_set_interval
    job = MyRecurringJob.schedule_job
    interval = MyRecurringJob.job_interval(job)
    assert_equal(interval, MyRecurringJob.default_interval)

    refute_equal(interval, 0)

    MyRecurringJob.set_job_interval(job, 0)
    job.reload # make sure it saved the change
    assert_equal(0, MyRecurringJob.job_interval(job))

  end

  def test_schedule_job_new_interval
    # nothing is scheduled when we start
    assert_nil(MyRecurringJob.next_scheduled_job)
    # schedule a job which will run immediately and reschedule itself immediately
    # (since not running automatically this will work)
    job = MyRecurringJob.schedule_job({interval:1})
    # now this job is scheduled
    assert_equal(job, MyRecurringJob.next_scheduled_job)
    assert_equal(1, MyRecurringJob.job_interval(job))

    job2 = MyRecurringJob.schedule_job({interval:0})
    assert_equal(job, job2)  # same object
    assert_equal(0, MyRecurringJob.job_interval(job2))

    job3 = MyRecurringJob.schedule_job({interval:1})
    assert_equal(job, job3)  # same object
    assert_equal(1, MyRecurringJob.job_interval(job3))


  end

  def test_schedule_job_new_first_start_time
    # nothing is scheduled when we start
    assert_nil(MyRecurringJob.next_scheduled_job)

    time1 = Time.now + 1.day
    job = MyRecurringJob.schedule_job({first_start_time:time1})
    # now this job is scheduled
    assert_equal(job, MyRecurringJob.next_scheduled_job)
    assert_equal(time1.to_i, job.run_at.to_i)

    job2 = MyRecurringJob.schedule_job({interval:0})  # no start time
    assert_equal(job, job2)  # same object
    assert_equal(time1.to_i, job2.run_at.to_i)

    time2 = Time.now
    job3 = MyRecurringJob.schedule_job({first_start_time:time2})
    assert_equal(job, job3)  # same object
    assert_equal(time2.to_i, job3.run_at.to_i)
  end

  def test_job_id
    # make sure the delayed job id is available to the job.
    assert_empty(RecurringJob.all)

    RecurringJobTest.last_job_id = nil
    job = MyRecurringJob.schedule_job({interval:1, action: :test_id, first_start_time: Time.now})
    assert_equal(RecurringJob.all, [job])

    refute(MyRecurringJob.get_option(job, :delayed_job_id))  # it's set only when the job is running
    assert_equal(:test_id, MyRecurringJob.get_option(job, :action))

    # now run the job from the queue
    Delayed::Worker.new.work_off

    assert_equal(job.id, @@last_job_id.to_i)

  end

end