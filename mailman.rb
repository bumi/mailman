require "net/imap"
require "logger"
class Mailman
  attr_accessor :imap, :options, :logger, :logging
  
  # options: 
  # :server =>
  # :port =>
  # :use_ssl =>
  # :username =>
  # :password =>
  # :logger => Logger.new(STDOUT)
  # :exception_mail_folder => "INBOX.error_importing"
  # :on_exception => Proc.new {|exception| ... }
  # :ensure_folders => []
  def initialize(options)
    self.options = options
    self.logger = options.keys.include?(:logger) ? options[:logger] : Logger.new(STDOUT)
    self.logging = options.keys.include?(:logging) ? options[:logging] : true
    self.ensure_folders(options[:ensure_folders]) if options[:ensure_folders]
  end
  
  def imap
    @imap ||= Net::IMAP.new(self.options[:server], self.options[:port], self.options[:use_ssl])
  end
  def imap!
    login unless connected?
    imap 
  end
  
  def login
    log("logging in with #{self.options[:username]}")
    @connected = imap.login(self.options[:username], self.options[:password])
  end
  def connected?
    @connected
  end
  
  def select(folder)
    log("selecting mailbox #{folder}")
    imap!.select(folder)
  end
  
  def with(folder,&block)
    begin 
      login
      select(folder)
      self.instance_eval(&block)
    rescue Exception => e
      fail(e)
    ensure
      log("ensure imap disconnect)")
      @imap.disconnect if @imap && !@imap.disconnected?
    end
  end
  
  def quit
    log("quit... (disconnect)")
    imap.disconnect unless imap.disconnected?
  end
  
  def expunge
    imap.expunge
  end
  
  def copy(message_id,target)
    log("copying #{message_id} to #{target}")
    imap!.uid_copy(message_id,target)
  end
  
  def store(message_id, target)
    log("storing #{target} in #{message_id}")
    imap!.uid_store(message_id, "+FLAGS", target)
  end
  
  def ensure_folders(folders)
    folders.each do |folder|
      create_folder(folder)
    end
  end
    
  def search(query='ALL')
    query = query.is_a?(Array) ? query : [query]
    imap!.uid_search(query)
  end
  
  def emails(query='ALL')
    mails = {}
    search(query).each{|message_id| mails[message_id] = imap.uid_fetch(message_id,'RFC822')[0].attr['RFC822'] }
    mails
  end
  
  def create_folder(name)
    log("creating folder #{name}")
    imap!.create(name) if not imap.list(*name.split("."))
  end
  
  def log(message)
    logger.info("[mailman] #{message}") if self.logging && self.logger
  end
  
  def fail(exception)
    log("ERROR: #{exception.message} - #{exception.class.name}")
    options[:on_exception].call(exception) if options[:on_exception]
  end
  
  def inspect
    "<Mailman: connected=#{self.connected?} - #{self.options.inspect}"
  end
end