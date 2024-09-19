# Read todays day from timestamp file if exists
def schedule_today()
    time_f = '/var/lib/one/readiness/start.timestamp'

    if File.exist?(time_f)
        mtime = File.stat(time_f).mtime.to_i.to_s
        return Date.strptime(mtime, '%s').cwday
    else
        # return current day
        return Date.today.cwday
    end
end
