require "rubygems"
require 'test/unit'
require "shoulda"
require 'mocha'
require "mailman"

class MailmanTest < Test::Unit::TestCase
  
  context "logging" do
    should "log to the provided logger" do
      logger = mock()
      logger.expects("info").with("[mailman] hello")
      man = mailman(:logger => logger, :logging => true)
      man.log "hello"
    end
    
    should "disable logging" do
      logger = mock()
      logger.expects("info").never
      man = mailman(:logger => logger, :logging => false)
      man.log "hello"
    end
  end
  
  context "login" do
    
    should "login to the imap object using username and password" do
      man = mailman(:username => "hello", :password => "world")
      imap = mock
      imap.expects(:login).with("hello", "world")
      man.expects(:imap).returns(imap)
      man.login
    end
    should "auto login if not connected" do
      man = mailman(:username => "hello", :password => "world")
      imap = mock
      imap.expects(:login).with("hello", "world").returns(true)
      man.expects(:imap).returns(imap).at_least(3)
      # call login
      man.imap!
      # don't call login
      man.imap!
    end
    
  end
  
  context "quit" do
    
    should "disconnect" do
      man = mailman()
      man.stubs(:connected?).returns(false)
      imap = mock()
      imap.expects(:disconnect)
      imap.expects(:disconnected?).returns(false)
      man.expects(:imap).times(2).returns(imap)
      man.quit
    end
    
  end
  
  context "search" do
    setup do
      @man = mailman()
      @man.stubs(:connected?).returns(true)
    end
    should "use imap uid_search to search for email" do
      @imap = mock()
      @imap.expects(:uid_search).with(["ALL"]).returns("result")
      @man.stubs(:imap).returns(@imap)
      @man.search("ALL")
    end
    
    should "accept a string or array" do
      @imap = mock()
      @imap.expects(:uid_search).with(["ALL"]).times(2).returns("result")
      @man.stubs(:imap).returns(@imap)
      @man.search("ALL")
      @man.search(["ALL"])
    end
  
  end
  
  context "emails" do
    setup do
      @man = mailman()
      @man.stubs(:connected?).returns(true)
    end
    
    should "return an hash with email_id as key and raw email as value" do
      @imap = mock()
      @imap.expects(:uid_search).with(["ALL"]).returns([1,2])
      [1,2].each do |i|
        email = mock(:attr=>{'RFC822' => "email_#{i}"})
        @imap.expects(:uid_fetch).with(i,'RFC822').returns([email])
      end
      @man.stubs(:imap).returns(@imap)
      emails = @man.emails
      assert_equal({1=> "email_1", 2 => "email_2"}, emails)
    end
  end
  
  context "with" do
    setup do
      @man = mailman()
      @man.stubs(:connected?).returns(true)
    end
    
    should "select provided folder" do
      @man.expects(:login)
      @man.expects(:select).with("INBOX")
      @man.expects(:quit)
      @man.with "INBOX" do end
    end
    
    should "eval provided block" do
      @man.expects(:instance_eval).with(any_parameters) # don't know how to test the same block
      @man.expects(:login)
      @man.expects(:select).with("INBOX")
      @man.expects(:quit)
      @man.with "INBOX" do
        puts "hallo"
      end
    end
    
    should "call fail on any exception" do
      block = Proc.new { raise StandardError }
      @man.expects(:login)
      @man.expects(:select).with("INBOX")
      @man.expects(:quit).never
      @man.expects(:fail).with(any_parameters)
      @man.with "INBOX", &block
    end
    
    should "ensure diconnection on exception" do
      @imap = mock()
      @imap.expects(:disconnect)
      @man.instance_variable_set("@imap",@imap)
      @man.expects(:login)
      @man.expects(:select).with("INBOX")
      @man.expects(:quit).never
      @man.expects(:fail).with(any_parameters)
      @man.with "INBOX" do 
        raise StandardError
      end
    end
  end
  
  
  def mailman(args={})
    Mailman.new({
      :username => "user",
      :password => "password",
      :use_ssl => false,
      :server => "mockserver.com",
      :port => 111,
      :logging => false
    }.merge(args))
  end
end
