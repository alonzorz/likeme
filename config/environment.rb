# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Likeme::Application.initialize!

#try big int integer 
#ActiveRecord::ConnectionAdapters::Mysql2Adapter::NATIVE_DATABASE_TYPES[:primary_key] = "BIGINT(8) UNSIGNED DEFAULT NULL auto_increment PRIMARY KEY"
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::NATIVE_DATABASE_TYPES[:primary_key] = "BIGSERIAL PRIMARY KEY"