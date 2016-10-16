require 'cinch'
require 'yaml'

module Notaru
  module Plugin
    class Quotes
      include Cinch::Plugin

      match Regexp.new('addquote (.+)|quoteadd (.+)', Regexp::IGNORECASE), method: :addquote
      match Regexp.new('quote(?: (.+))?', Regexp::IGNORECASE), method: :quote

      def initialize(*args)
        super

        @quotes_file = config[:quotes_file]
      end

      def addquote(m, quote)
        if m.channel && !m.channel.opped?(m.user) && !m.user.authed?
          return m.reply("Only channel ops and registered users can add quotes.")
        end

        # make the quote
        new_quote = { 'quote' => quote,
                      'added_by' => m.user.authed? ? m.user.authname : m.user.nick,
                      'channel' => m.channel.name,
                      'created_at' => Time.now.utc,
                      'deleted' => false }

        # add it to the list
        existing_quotes = retrieve_quotes || []
        existing_quotes << new_quote

        # find the id of the new quote and set it based on where it was placed in the quote list
        new_quote_index = existing_quotes.index(new_quote)
        existing_quotes[new_quote_index]['id'] = new_quote_index + 1

        # write it to the file
        output = File.new(@quotes_file, 'w')
        output.puts YAML.dump(existing_quotes)
        output.close

        # send reply that quote was added
        m.reply "#{m.user.nick}: Quote successfully added as \\#{new_quote_index + 1}."
      end

      def quote(m, search = nil)
        quotes = retrieve_quotes.delete_if { |q| q['deleted'] == true }
        if search.nil? # we are pulling random
          quote = quotes.sample
          m.reply "#{m.user.nick}: \\#{quote['id']} - #{fmt_quote(quote['quote'])}"
        elsif search.to_i != 0 # then we are searching by id
          quote = quotes.find { |q| q['id'] == search.to_i }
          if quote.nil?
            m.reply "#{m.user.nick}: No quotes found."
          else
            m.reply "#{m.user.nick}: \\#{quote['id']} - #{fmt_quote(quote['quote'])}"
          end
        else
          quotes.keep_if { |q| q['quote'].downcase.include?(search.downcase) }
          if quotes.empty?
            m.reply "#{m.user.nick}: No quotes found."
          else
            quote = quotes.first
            m.reply "#{m.user.nick}: \\#{quote['id']} - #{fmt_quote(quote['quote'])}"
            m.reply "The search term also matched on quote IDs: #{quotes.map { |q| q['id'] }.join(', ')}" if quotes.size > 1
          end
        end
      end

      #--------------------------------------------------------------------------------
      # Protected
      #--------------------------------------------------------------------------------

      protected

      def retrieve_quotes
        output = File.new(@quotes_file, 'r')
        quotes = YAML.load(output.read)
        output.close

        quotes
      end

      def fmt_quote(quote)
        new_quote = quote
        userlist = @bot.user_list.sort_by { |x| x.nick.length }
        
        userlist.each do |user|
          if new_quote.include?(user.nick)
            repl = user.nick.gsub("", "\u200D")
            log "quote: found name #{user.nick}, replacing with ZWS"
            new_quote.gsub!(user.nick, repl)
          end
        end

        return new_quote
      end
    end
  end
end
