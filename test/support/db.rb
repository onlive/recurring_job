# Copyright (C) 2015 OL2, Inc. All Rights Reserved.

# set up database just for testing. When using the gem, users will set up
# the database structure when setting up delayed job to work with their code and
# we use that same database.
ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => ':memory:'

# set up the DelayedJob schema in our test database
ActiveRecord::Base.connection.create_table "delayed_jobs", force: true do |t|
  t.integer  "priority",   default: 0, null: false
  t.integer  "attempts",   default: 0, null: false
  t.text     "handler",                null: false
  t.text     "last_error"
  t.datetime "run_at"
  t.datetime "locked_at"
  t.datetime "failed_at"
  t.string   "locked_by"
  t.string   "queue"
  t.datetime "created_at"
  t.datetime "updated_at"
end
