# -*- encoding : utf-8 -*-
ENV["RAILS_ENV"] = "cucumber"

require "wagn"
require File.join Wagn.card_gem_root, "spec/support/simplecov_helper.rb"
require "simplecov"
require "minitest/autorun"

require "rspec/expectations"
World(RSpec::Matchers)
require "rspec-html-matchers"
World(RSpecHtmlMatchers)

require "pry"

# IMPORTANT: This file is generated by cucumber-rails - edit at your own peril.
# It is recommended to regenerate this file in the future when you upgrade to a
# newer version of cucumber-rails. Consider adding your own code to a new file
# instead of editing this one. Cucumber will automatically load all
# features/**/*.rb files.
Before("@background-jobs, @delayed-jobs, @javascript") do
  DatabaseCleaner.strategy = :truncation
end
Before("~@background-jobs", "~@delayed-jobs", "~@javascript") do
  DatabaseCleaner.strategy = :transaction
end
After("@background-jobs, @delayed-jobs, @javascript") do
  Card.seed_test_db
end

require "cucumber/rails"
require "test_after_commit"

# Capybara defaults to XPath selectors rather than Webrat's default of CSS3. In
# order to ease the transition to Capybara we set the default here. If you'd
# prefer to use XPath just remove this line and adjust any selectors in your
# steps to use the XPath syntax.
Capybara.default_selector = :css
Capybara.default_wait_time = 5
Cardio.config.paging_limit = 10
# By default, any exception happening in your Rails application will bubble up
# to Cucumber so that your scenario will fail. This is a different from how
# your application behaves in the production environment, where an error page
# will be rendered instead.
#
# Sometimes we want to override this default behaviour and allow Rails to rescue
# exceptions and display an error page
# (just like when the app is running in production).
# Typical scenarios where you want to do this is when you test your error pages.
# There are two ways to allow Rails to rescue exceptions:
#
# 1) Tag your scenario (or feature) with @allow-rescue
#
# 2) Set the value below to true. Beware that doing this globally is not
# recommended as it will mask a lot of errors for you!
#
ActionController::Base.allow_rescue = false

# Remove/comment out the lines below if your app doesn't have a database.
# For some databases (like MongoDB and CouchDB) you may need to
# use :truncation instead.
# begin
#   DatabaseCleaner.strategy = :transaction
# rescue NameError
#   raise 'You need to add database_cleaner to your Gemfile (in the :test group)
# if you wish to use it.'
# end

# You may also want to configure DatabaseCleaner to use different strategies for
# certain features and scenarios.
# See the DatabaseCleaner documentation for details. Example:
#
#   Before('@no-txn,@selenium,@celerity,@javascript') do
#     DatabaseCleaner.strategy = :truncation, {except: %w[widgets]}
#   end
#
#   Before('~@no-txn', '~@selenium', ~@celerity', '~@javascript') do
#   DatabaseCleaner.strategy = :transaction
# end
#

# Possible values are :truncation and :transaction
# The :transaction strategy is faster, but might give you threading problems.
# See https://github.com/cucumber/cucumber-rails/blob/master/features/choose_javascript_database_strategy.feature
Cucumber::Rails::Database.javascript_strategy = :truncation

# `LAUNCHY=1 cucumber` to open page on failure
After do |scenario|
  save_and_open_page if scenario.failed? && ENV["LAUNCHY"]
end

# `FAST=1 cucumber` to stop on first failure
After do |scenario|
  Cucumber.wants_to_quit = ENV["FAST"] && scenario.failed?
end

# `DEBUG=1 cucumber` to drop into debugger on failure
After do |scenario|
  next unless ENV["DEBUG"] && scenario.failed?
  puts "Debugging scenario: #{scenario.name}"
  if respond_to? :debugger
    debugger
  elsif binding.respond_to? :pry
    binding.pry
  else
    puts "Can't find debugger or pry to debug"
  end
end

# `STEP=1 cucumber` to pause after each step
AfterStep do |result, step|
  next unless ENV["STEP"]
  unless defined?(@counter)
    #puts "Stepping through #{scenario.name}"
    @counter = 0
  end
  @counter += 1
  #print "At step ##{@counter} of #{scenario.steps.count}. Press Return to"\
  #      " execute..."
  print "Press Return to execute next step...\n(d=debug, c=continue, s=step, a=abort)"
  case STDIN.getch
  when "d" then
    binding.pry
  when "c" then
    ENV.delete "STEP"
  when "a" then
    Cucumber.want_to_quit = true
  end
end
