require 'active_support/all'

class Job
  def initialize
    @dir = ENV['DB_DIR'].blank? ? '.' : ENV['DB_DIR']
  end

  def active_file; "#{@dir}/job_active"; end
  def done_file; "#{@dir}/job_done"; end
  def reset_file; "#{@dir}/job_reset"; end

  def start
    log "Job started"
    if File.exists? active_file
      rm active_file
    end
    
    File.open(active_file, "w") {}
  end
  
  def is_active?
    if File.exist?( active_file )
      if File.mtime( active_file ) < 2.minutes.ago
        return false
      else
        return true
      end
    end

    false
  end

  def done
    log "Job done"
    rm active_file
    File.open(done_file, "w") {}
    File.open(reset_file, "w") {}
  end

  def reset_check
    if File.exist? reset_file
      rm reset_file
      log "Needs reset"
      return true
    end

    return false
  end

  def rm file
    if File.exist? file
      File.unlink file
    end
  end

  def log message
    puts message
    system( "echo $(date +\"%Y-%m-%dT%H:%M:%S\") #{message} >> #{@dir}/log" )
  end
end
