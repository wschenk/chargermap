require 'active_support/all'

class Job
  def initialize
    @dir = ENV['DB_DIR'] || '.'
  end

  def active_file; "#{@dir}/job_active"; end
  def done_file; "#{@dir}/job_done"; end
  def reset_file; "#{@dir}/job_reset"; end

  def start
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
    rm active_file
    File.open(done_file, "w") {}
    File.open(reset_file, "w") {}
  end

  def is_current?
    if !File.exists?( done_file )
      return false
    end

    if File.mtime( done_file ) < 1.day.ago
      return false
    end

    return true
  end

  def reset_check
    if File.exist? reset_file
      rm reset_file
      return true
    end

    return false
  end

  def rm file
    if File.exist? file
      File.unlink file
    end
  end
end

if __FILE__ == $0
  j = Job.new

  def timeout_test

    puts "Is active? #{j.is_active?}"
    puts "Is current? #{j.is_current?}"

    puts "-- Calling start"
    j.start
    
    puts "Is active? #{j.is_active?}"
    puts "Is current? #{j.is_current?}"
    
    puts "-- Calling done"
    
    j.done
    
    puts "Is active? #{j.is_active?}"
    puts "Is current? #{j.is_current?}"
  end

  def poll_test
    j = Job.new
    while true
      if !j.is_active? && !j.is_current?
        puts "Starting job"
        j.start
        Thread.new do
          sleep 5
          puts "Job done"
          j.done
        end
      end

      puts "Active #{j.is_active?} Current #{j.is_current?}"
      sleep 1
    end
  end

  poll_test
end
