# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20131026075447) do

  create_table "answers", :force => true do |t|
    t.integer  "user_id"
    t.integer  "question_id"
    t.text     "text"
    t.text     "comment"
    t.boolean  "anonymous",      :default => false
    t.string   "ranked_by_user"
    t.datetime "created_at",                        :null => false
    t.datetime "updated_at",                        :null => false
  end

  create_table "attendances", :force => true do |t|
    t.integer "user_id",     :limit => 8, :null => false
    t.integer "event_id",    :limit => 8, :null => false
    t.string  "rsvp_status", :limit => 1
  end

  add_index "attendances", ["rsvp_status"], :name => "index_attendances_on_rsvp_status"
  add_index "attendances", ["user_id"], :name => "index_attendances_on_user_id"

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
  end

  add_index "delayed_jobs", ["priority", "run_at"], :name => "delayed_jobs_priority"

  create_table "events", :force => true do |t|
    t.string   "name"
    t.datetime "start_time"
    t.datetime "end_time"
    t.string   "location"
    t.text     "description"
  end

  add_index "events", ["end_time"], :name => "index_events_on_end_time"
  add_index "events", ["location"], :name => "index_events_on_location"

  create_table "friendships", :id => false, :force => true do |t|
    t.integer "user_id",   :limit => 8, :null => false
    t.integer "friend_id", :limit => 8, :null => false
  end

  create_table "pages", :force => true do |t|
    t.string "name"
    t.string "category"
  end

  add_index "pages", ["category"], :name => "index_pages_on_category"

  create_table "questions", :force => true do |t|
    t.integer  "user_id"
    t.text     "text"
    t.boolean  "anonymous",          :default => false
    t.boolean  "allow_referrals",    :default => true
    t.string   "category"
    t.boolean  "is_multiple_choice", :default => false
    t.text     "choices"
    t.float    "bounty",             :default => 0.0
    t.string   "gender_limit"
    t.boolean  "friends_limit"
    t.integer  "for_people_like"
    t.float    "spam_counter",       :default => 0.0
    t.float    "offensive_counter",  :default => 0.0
    t.datetime "created_at",                            :null => false
    t.datetime "updated_at",                            :null => false
  end

  create_table "scores", :force => true do |t|
    t.integer "user_id",   :limit => 8
    t.integer "friend_id", :limit => 8
    t.string  "category",  :limit => 1
    t.float   "score"
  end

  add_index "scores", ["category"], :name => "index_scores_on_category"
  add_index "scores", ["score"], :name => "index_scores_on_score"
  add_index "scores", ["user_id"], :name => "index_scores_on_user_id"

  create_table "user_page_relationships", :force => true do |t|
    t.integer "user_id",           :limit => 8, :null => false
    t.integer "page_id",           :limit => 8, :null => false
    t.string  "relationship_type", :limit => 1
  end

  add_index "user_page_relationships", ["relationship_type"], :name => "index_user_page_relationships_on_relationship_type"
  add_index "user_page_relationships", ["user_id"], :name => "index_user_page_relationships_on_user_id"

  create_table "users", :force => true do |t|
    t.string   "provider"
    t.string   "name"
    t.string   "oauth_token"
    t.datetime "oauth_expires_at"
    t.datetime "created_at",                                         :null => false
    t.datetime "updated_at",                                         :null => false
    t.boolean  "active",                          :default => false
    t.string   "email"
    t.datetime "last_fb_update"
    t.string   "location"
    t.string   "birthday"
    t.string   "hometown"
    t.text     "quotes"
    t.string   "relationship_status"
    t.string   "significant_other"
    t.string   "gender"
    t.string   "age"
    t.text     "bio"
    t.datetime "last_foregin_fb_update"
    t.datetime "last_relationship_status_update"
    t.float    "reputation",                      :default => 0.0
    t.float    "credit",                          :default => 0.0
    t.text     "settings"
  end

  add_index "users", ["birthday"], :name => "index_users_on_birthday"

end
