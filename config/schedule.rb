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
# every 20.minutes do
every 1.day, at: ['0:20','1:20','2:20','3:20','4:20','5:20','6:20','7:20','8:20','9:20','10:20','11:20','12:20','13:20','14:20','15:20','16:20','17:20','18:20','19:20','20:20','21:20','22:20','23:20'] do
  runner "Product.get_file"
end
every 1.day, :at => '18:00' do
  runner "Product.load_by_api"
end
# every 20.minutes do
every 1.day, at: ['0:10','1:10','2:10','3:10','4:10','5:10','6:10','7:10','8:10','9:10','10:10','11:10','12:10','13:10','14:10','15:10','16:10','17:10','18:10','19:10','20:10','21:10','22:10','23:10'] do
  runner "Product.get_file_vstrade"
end
every 1.day, at: ['0:40','1:40','2:40','3:40','4:40','5:40','6:40','7:40','8:40','9:40','10:40','11:40','12:40','13:40','14:40','15:40','16:40','17:40','18:40','19:40','20:40','21:40','22:40','23:40'] do
  runner "Product.csv_param"
end
# every 20.minutes do
#   runner "Product.csv_param"
# end
