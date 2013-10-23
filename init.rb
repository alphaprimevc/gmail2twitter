require 'rubygems'
require 'bundler'
Bundler.require(:default)
require 'yaml'

module Gmail2Twitter
  attr_accessor :gmail

  def self.configure(config)
    ::Twitter.configure do |c|
      c.consumer_key = config['twitter']['consumer_key']
      c.consumer_secret = config['twitter']['consumer_secret']
    end
    @gmail_username = config['gmail']['username']
    @gmail_password = config['gmail']['password']
    @authors = config['authors']
    @email2author = {}
    @authors.each do |k,v|
      v['emails'].each do |e|
        @email2author[e.downcase] = k
      end if v['emails']
    end
    self.gmail
  end

  def self.gmail
    @gmail ||= Gmail.new(@gmail_username,@gmail_password)
    unless @gmail.logged_in?
      STDERR.puts "ERROR: unable to login to gmail"
      exit(1)
    end
    @gmail
  end

  def self.tweet_as(author_name,text)
    puts "tweeting #{text} as #{author_name}"
    author = @authors[author_name]
    user = Twitter::Client.new({
      :oauth_token => author['twitter_token'],
      :oauth_token_secret => author['twitter_token_secret']
    })
    user.update(text)
  end

  def self.retweet_as(author_name,tweet)
    return unless tweet
    puts "retweeting #{tweet} as #{author_name}"
    author = @authors[author_name]
    user = Twitter::Client.new({
      :oauth_token => author['twitter_token'],
      :oauth_token_secret => author['twitter_token_secret']
    })
    user.retweet(tweet)
  end

  def self.tweet_emails
    self.gmail.inbox.emails(:unread).each do |email|
      email.mark(:read)
      from = email.message.from.first.downcase
      if author = @email2author[from]
        next unless email.message.in_reply_to.nil?
        next unless url_match = email.message.body.match(URI.regexp(['http','https']))
        text = url = url_match[0]
        max_tweet_length = 140 - 21
        if subject = email.message.subject
          subject = subject[0,max_tweet_length] if subject.length > max_tweet_length
          text = "#{subject} #{url}" if subject.length > 0
        end
        tweet = tweet_as(author,text)
        if tweet && (retweeters = @authors[author]['retweeters'])
          retweeters.each do |retweeter|
            retweet_as(retweeter,tweet.id)
          end
        end
      end
    end
  end
end

Gmail2Twitter.configure(YAML::load(File.open(ARGV[0] || 'config.yml')))
Gmail2Twitter.tweet_emails
