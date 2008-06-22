require 'socket'
require 'timeout'
require 'net/denon/status'

module Net ; module Denon

  #
  # == Net::Denon::Session
  #
  # Provides DENON AVR control protocol client functionality.
  #
  # == Overview
  #
  # The DENON AVR control protocol allows a client to send commands to a Denon
  # AVR reciever via its embedded telnet server. This library currently
  # implements version 5.1.0_a for model AVR-4308.
  #
  # == Examples
  #
  # === Log in and send a command
  #
  #   denon = Net::Denon.new("10.0.1.201")
  #   denon.power_on
  #   denon.close
  #
  # == References
  #
  # This library implements the DENON AVR control protocol as documented by
  # Denon at:
  # http://usa.denon.com/AVR-4308CISerialProtocol_Ver5.1.0a.pdf
  #
  class Session
  
    # Creates a new Net::Denon object and connects it to the telnet port (23) of
    # the Denon receiver on the named host.
    #
    # +options+ is a hash of options.  The following example lists all options
    # and their default values.
    #
    #   denon = Net::Denon::new(
    #     :host       => "10.0.1.201", # default: nil
    #     :port       => 23,           # default: 23
    #     :wait_time  => 0.2,          # default: 0.2 sec
    #     :timeout    => 1,            # default: 1 sec
    #     :log        => "debug.txt",  # default: nil (no output)
    #     :proxy      => proxy,        # default: nil
    #     )
    #
    # The options have the following meanings:
    #
    # host:: the hostname or IP address to connect to, as a String.
    #
    # port:: the port to connect to; defaults to 23.
    #
    # wait_time:: the amount of time to wait for a response after sending
    #             a command; default is 0.2 sec.
    #
    # timeout:: the amount of time to wait trying to connect.  Exceeding
    #           this timeout value causes a Timeout::Error to be raised.
    #           Defaults to 1 sec.
    #
    # log:: commands and output will be dumped to this file; defaults
    #       to no output.
    #
    # proxy:: a proxy object to be used instead of opening a direct connection
    #         to the host.
    #
    def initialize(options)
      @options = options
      @options[:port]      = 23  unless @options.has_key?(:port)
      @options[:wait_time] = 0.2 unless @options.has_key?(:wait_time)
      @options[:timeout]   = 1   unless @options.has_key?(:timeout)
      
      if @options.has_key?(:log)
        @log = File.open(@options[:log], "a+")
        @log.sync = true
      end
      
      if @options.has_key?(:proxy)
        @sock = @options[:proxy]
      else
        message = "Trying #{@options[:host]}...\n"
        yield(message) if block_given?
        log(message)
        
        begin
          Timeout::timeout(@options[:timeout]) do
            @sock = TCPSocket.open(@options[:host], @options[:port])
          end
        rescue Timeout::Error
          log("Timed out while opening a connection to #{@options[:host]}.\n")
          raise Timeout::Error, message
        rescue Exception => e
          log(e.to_s + "\n")
          raise
        end
        @sock.sync = true
        message = "Connected to #{@options[:host]}.\n"
        log(message)
        yield(message) if block_given?
      end
      @status = Net::Denon::Status::new
    end
  
    # Disconnects from the server.
    def close
      @sock.close
    end
  
    # Returns true if connection to receiver is completely closed.
    def closed?
      @sock.closed?
    end
    
    def query
      send_command "PW?"
      send_command "MU?"
      send_command "MV?"
      send_command "SI?"
      send_command "ZM?"
      # send_command "CV?"
    end
    
    def status
      check_status
      @status
    end
    
    def on
      send_command "PW?"
      check_status
      send_command "PWON" unless @status.on?
    end
    
    def standby
      send_command "PW?"
      check_status
      send_command "PWSTANDBY" unless @status.standby?
    end
    
    def mute
      send_command "MU?"
      check_status
      send_command "MUON" unless @status.mute?
    end
    
    def unmute
      send_command "MU?"
      check_status
      send_command "MUOFF" if @status.mute?
    end
    
    def master_volume=(volume)
      v = volume.to_i
      if (v > 0 && v < 99) then
        send_command("MV#{v}")
      end
    end
    
    protected
    
    def log(message)
      @log.write(message) if @options.has_key?(:log)
    end
    
    def send_command(string)
      string += "\r"
      length = string.length
      while 0 < length
        IO::select(nil, [@sock])
        length -= @sock.syswrite(string[-length..-1])
      end
      sleep 0.1
      check_status
    end
    
    def check_status
      buffer = ''
      line = "\r"

      until(line[-1] == 13 and not IO::select([@sock], nil, nil, @options[:wait_time]))
        buffer = @sock.readpartial(1024)
        line += buffer
      end
      message = line.gsub("\r", "\n")
      log("received: #{message}")
      @status.update(line)
    end
  
  end

end ; end