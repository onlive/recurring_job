# Copyright (C) 2014-2015 OL2, Inc. All Rights Reserved.
require 'active_record'
require 'delayed_job_active_record'

class RecurringJob < Struct.new(:options )
  # (parts inspired by https://gist.github.com/JoshMcKin/1648242)

  def self.logger=(new_logger)
    puts "Setting logger to #{new_logger.inspect}"
    @@logger = new_logger
  end

  def self.logger
    @@logger ||= Logger.new(STDOUT)
    @@logger
  end

  def logger
    RecurringJob.logger
  end

  def self.schedule_job(options = {}, this_job=nil)
    # schedule this job (if you just want job to run once, just use queue_once )
    # this_job is currently running instance (if any)(so we can check against it)
    # options -
    #   :interval => num_seconds - how often to schedule the job
    #               default, once a day
    #               (time between job runs (from end of one to beginning of next)
    #   :queue  => name of queue to use
    #              default: the name of this class
    #              only one job can be scheduled at a time for any given queue
    #   :first_start_time => specify a specific time for this run, then use interval after that

    # Plus any other options (if any) you want sent through to the underlying job.

    options ||= {}  # in case sent in explicitly as nil
    options[:interval] ||= default_interval
    options[:queue] ||= default_queue

    queue_name = options[:queue]

    other_job = next_scheduled_job(this_job, queue_name)
    if other_job
      logger.info "#{queue_name} job is already scheduled for #{other_job.run_at}."
      # Still set any new start time or interval options for next time.
      if job_interval(other_job) != options[:interval].to_i
        logger.info "    Setting interval to #{options[:interval]}"
        set_job_interval(other_job, options[:interval])
      end
      if options[:first_start_time] && options[:first_start_time] != other_job.run_at
        logger.info "    Setting start time to #{options[:first_start_time]}"

        other_job.run_at = options[:first_start_time]
        other_job.save
      end
    else
      # if start time is specified, use it ONLY this time (to start), don't pass on in options
      run_time = options.delete(:first_start_time)
      run_time ||=  Time.now + options[:interval].to_i # make sure it's an integer (e.g. if sent in as 1.day)
      other_job = Delayed::Job.enqueue self.new(options), :run_at => run_time, :queue=> queue_name
      logger.info "The next #{queue_name} job has been scheduled for #{other_job.run_at}."
    end
    other_job
  end

  def self.unschedule_job
    # shortcut for deleting the job from Delayed Job
    # returns true if there was a job to delete, false otherwise
    recurring_job = self.next_scheduled_job
    recurring_job.destroy if recurring_job
    return recurring_job  # true if there was a job to unschedule
  end

  def self.in_queue_or_running?(queue)
    # is this job currently in progress?
    # (the job is out of the queue when it's done.)
    queue ||= default_queue
    job = Delayed::Job.find_by(queue:queue)
    logger.debug("Checking #{queue}: #{job.inspect}")
    job
  end

  def self.queue_once(options = {})
    # just run this add the queue to run one time only (not scheduled)
    # IMPORTANT: don't put in same queue name as recurring job and DON'T specify an interval in the options!
    # Can use the queue field, but do not use the job name!
    queue = options[:queue]
    raise "Can't run Recurring Job once in queue: #{default_queue}" if queue == default_queue
    Delayed::Job.enqueue(self.new(options), :queue => queue)
  end

  def self.default_interval
    1.day
  end

  def self.default_queue
    self.name
  end

  def self.next_scheduled_job(this_job=nil, queue_name = nil)
    # return job if it exists
    queue_name ||= default_queue
    conditions = ['queue = ? AND failed_at IS NULL', queue_name]

    unless this_job.blank?
      conditions[0] << " AND id != ?"
      conditions << this_job.id
    end

    Delayed::Job.where(conditions).first  #?? failed_at:nil
  end

  def self.job_interval(job)
    # given a job from the queue
    # parse the handler yaml and give back the current interval
    # nil means no interval set
    y = YAML.load(job.handler)
    y.options && y.options[:interval].to_i
  end

  def self.running?(queue=nil)
    # is this job currently running?
    queue ||= default_queue
    job = Delayed::Job.find_by(queue:queue)
    job && job.locked_by
  end

  def self.job_id_running?(job_id)
    # is a job with the given id running?
    job = Delayed::Job.find_by(id:job_id)  # don't use find, don't want to raise an error if not found
    #logger.debug("Is job #{job_id} running? #{job.inspect}")
    job && job.locked_by
  end

  def self.set_option(job, option, value)
    # given a job from the queue,
    # parse the handler yaml and set options[option] to value
    y = YAML.load(job.handler)
    y.options ||= {}
    y.options[option] = value
    job.handler = y.to_yaml
    job.save!
  end

  def self.set_job_interval(job, interval)
    # given a job from the queue
    # parse the handler yaml and set the job interval
    interval ||= default_interval
    set_option(job, :interval, interval.to_i)
  end

  def self.all
    # just assume any job that uses a named queue is one of ours - not always true, but maybe close.
    Delayed::Job.all.where.not(queue:nil)
  end

  def self.list_job_intervals
    # lists all jobs that have a queue associated with them and intervals (if any)
    # {queue_name => {interval:interval, next_run:<run_at>}}
    job_list = {}
    self.all.each do |job|
      queue = job.queue
      next unless queue
      job_list[queue] = {interval:self.job_interval(job), next_run:job.run_at}
    end
    job_list
  end

  def enqueue(job)
    # when this job is put in the queue,
  end

  def perform
    logger.debug("PERFORMING #{self.class.name} - #{options}")
    # should be overridden by real job.
  end

  def before(job)
    # Always send in the job_id so that the RecurringJob can use it if it needs it.
    # (during perform we don't have access to "job")
    options[:delayed_job_id] = job.id.to_s
  end

  def after(job)
    # Always reschedule this job when we're done.  Whether there's an error in this run
    # or not, we always want to reschedule if an interval was specified
    if options[:interval]
      #  if an interval was specified, make sure there's a future job using the same options as before.
      #  Otherwise, this is a one time run so don't reschedule.
      options.delete(:delayed_job_id) # don't pass on the delayed job id
      # logger.debug("Scheduling again: #{options.inspect}")
      self.class.schedule_job(options, job)
    end
  end

end
