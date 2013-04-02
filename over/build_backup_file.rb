require './lib/backup_controller.rb'
require './lib/backup_source.rb'

# [ 'auth.log', 'dmesg', 'syslog', 'nginx', 'mysql' ].each do |path|
#   Backup::Controller.add('/var/log/' + path)
# end

sources = [ 'auth.log', 'dmesg', 'syslog', 'nginx', 'mysql' ].map { |path| '/var/log/' + path }
Backup::Controller.add *sources

Backup::Controller.backup
