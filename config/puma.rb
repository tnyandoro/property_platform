threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

server_port = ENV.fetch("PORT", 3000)
bind "tcp://0.0.0.0:#{server_port}"

plugin :tmp_restart
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
