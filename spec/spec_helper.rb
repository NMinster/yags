# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path(File.join(File.dirname(__FILE__),'..','config','environment'))
require 'spec/autorun'
require 'spec/rails'
require 'shoulda'

# Uncomment the next line to use webrat's matchers
require 'webrat/integrations/rspec-rails'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir[File.expand_path(File.join(File.dirname(__FILE__),'support','**','*.rb'))].each {|f| require f}

Spec::Runner.configure do |config|
  config.use_transactional_fixtures = true
  config.use_instantiated_fixtures  = false
  config.fixture_path = RAILS_ROOT + '/spec/fixtures/'

  config.include Webrat::Matchers, :type => :views

  config.include ModelHelpers
  config.extend UserMacros
  config.include SessionHelpers
  config.include HttpMethodsHelpers
end

Spec::Matchers.define :be_authorized do

  match do |response|
    response.response_code != 401
  end

  failure_message_for_should do |response|
    "expected the response to not be 401 but was #{response.response_code}"
  end

  failure_message_for_should_not do |response|
    "expected the response code to be 401 but was #{response.response_code}"
  end

  description do
    "expected response code to be 401"
  end
end
