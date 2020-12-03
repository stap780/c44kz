# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever
# очистить cron -> crontab -r
# просмотр cron -> crontab -l
# сохранение и запуск cron в режиме девелопмент (писать в терминале) ->  whenever --set environment='development' --write-crontab или
# RAILS_ENV=development whenever --write-crontab
# RAILS_ENV=production whenever --write-crontab
# очистить cron - bundle exec whenever --clear-crontab
# сервер минус 3 часов (лето) и минус 4 (зима)

env :PATH, ENV['PATH']
env "GEM_HOME", ENV["GEM_HOME"]
set :output, "#{path}/log/cron.log"
set :chronic_options, :hours24 => true

# every 1.hours do
every 20.minutes do
# every 1.day, at: ['1:00','3:00', '5:00', '7:00', '9:00', '11:00', '13:00', '15:00', '17:00', '19:00', '21:00', '23:00'] do
  runner "Product.get_file"
end
every 1.day, :at => '18:00' do
  runner "Product.load_by_api"
end
every 20.minutes do
  runner "Product.get_file_vstrade"
end
every 1.day, at: ['1:30', '3:30', '5:30', '7:30', '9:30', '11:30', '13:30', '15:30', '17:30'] do
  runner "Product.csv_param"
end
