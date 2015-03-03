# RecurringJob

RecurringJob creates a framework for creating custom DelayedJob jobs that are automatically rescheduled to run again.

## Installation
RecurringJob requires delayed_job_active_record ( > 4.0).
Follow the instructions to [install DelayedJob](https://github.com/collectiveidea/delayed_job_active_record) first.

Then add this line to your application's Gemfile:

```ruby
gem 'recurring_job'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install recurring_job

By default, RecurringJob logs to STDOUT. If you want it to log to your rails logger, put the following somewhere in your rails configuration files
(I use environment.rb)

```ruby
# log RecurringJob output to the rails log
RecurringJob.logger = Rails.logger
```

## Usage

RecurringJob extends the functionality of [Custom Jobs](https://github.com/collectiveidea/delayed_job#custom-jobs)
within DelayedJob. It uses the job's queue field to identify each type of recurring job, and to ensure a single instance of each
one is scheduled in the job queue at a time.

To use RecurringJob, you need to create a custom job class for each type of job you wish to schedule.
I like to put job classes in a `lib/jobs` folder in my rails app, but you're free to put them anywhere you like.

This example, which is similar to how we use RecurringJob at OnLive, shows how to subclass the RecurringJob class and provide a `perform` method that does the actual work.
We can send in our own options (in this example an `app_id` for a database Model named App) and those will be passed on each
time when the job is scheduled.  In addition we are automatically passed in the job id of the DelayedJob job, which in this
case we use for locking.

```ruby
class AppStatusJob < RecurringJob
   # As a recurring job, we just provide the "perform" method to do the actual work
   # We can add send in our own options (in this example an app_id for a database model named App)
    # that will be passed on each time when the job is scheduled

  def perform
    return unless options
    app_id = options[:app_id]
    recurring_job_id = options[:delayed_job_id]

    apps_to_process = app_id ? App.where(id:app_id) : App.all

    apps_to_process.each do |app|
      app.lock_for_status_check(recurring_job_id) do
        # if no one else is modifying the app right now
        # this block gets executed
        app.do_whatever_it_means_to_check_status
      end
    end
  end

  def after(job)
    super   # have to allow RecurringJob to do its work!!
    send_email_about_job_success(job)
  end

end
```
We can run this job a single time to check a single app

```ruby
AppStatusJob.queue_once(app_id:App.first.id)
```

Or we can set it up to run as a scheduled job
```ruby
AppStatusJob.schedule_job(interval:1.hours)
```

Or we can set it up to run for each particular app on a schedule, using the (unique)
name of the app as the name of the queue

```ruby
App.all.each do |app|
  AppSyncJob.schedule_job(interval:2.hours, app_id:app.id, queue:app.name)
end
```

Because AppStatusJob has been set up as a RecurringJob, the scheduled jobs will automatically add themselves back into the
queue to run an hour after they finish (or whatever interval you choose), continuing indefinitely! And like all DelayedJobs,
you can specify actions to happen when these jobs succeed, or fail, and they live in the DelayedJob queue between runs.
(See more info about [DelayedJob hooks](https://github.com/collectiveidea/delayed_job#hooks)).

*Important:* If you implement any of the DelayedJob hooks (`before`, `after`, `success`, `error`, `failure`, or `enqueue`) in your RecurringJob, you must call super to allow the RecurringJob hooks
to do its work!

## Contributing

1. Fork it ( https://github.com/[my-github-username]/recurring_job/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
