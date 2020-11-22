source 'https://rubygems.org'
git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end
# ruby '2.4.4'
gem 'rails', '~> 5.0.7', '>= 5.0.7.2'
gem 'puma', '~> 3.0'
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '>= 1.3.0'
gem 'coffee-rails', '~> 4.2'
gem 'jquery-rails'
gem 'jbuilder', '~> 2.5'
gem 'bootstrap'
gem 'devise'
gem 'high_voltage'
gem 'simple_form'
gem 'rest-client'
gem 'nokogiri'
gem 'cocoon'
gem 'will_paginate'
gem 'ransack'
gem 'roo'
gem 'roo-xls'
gem 'whenever', require: false
gem 'figaro'
gem 'mechanize'
gem 'pg', '~> 0.18'
gem 'delayed_job_active_record'
gem 'daemons'
gem 'bcrypt_pbkdf', '< 2.0', :require => false
gem 'ed25519', '~> 1.2', '>= 1.2.4'
gem 'addressable', '~> 2.4'


group :development, :test do
  gem 'byebug', platform: :mri
end
group :development do
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '~> 3.0.5'
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'better_errors'
  gem 'capistrano'#, '~> 3.0.1'
  gem 'capistrano-bundler'
  gem 'capistrano-rails'#, '~> 1.1.0'
  gem 'capistrano-rails-console'
  gem 'capistrano-rvm'#, '~> 0.1.1'
  gem 'capistrano3-unicorn'
  gem 'capistrano3-delayed-job', '~> 1.0'
  gem 'hub', :require=>nil
  gem 'rails_layout'
end
group :production do
  gem 'unicorn'
end
