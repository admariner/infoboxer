# frozen_string_literal: true

require 'strscan'

module Infoboxer
  class Parser
    class Context # rubocop:disable Metrics/ClassLength
      attr_reader :lineno
      attr_reader :traits

      def initialize(text, traits = nil)
        @lines = text
                 .gsub(/<!--.*?-->/m, '') # FIXME: will also kill comments inside <nowiki> tag
                 .split(/[\r\n]/)
        @lineno = -1
        @traits = traits || MediaWiki::Traits.default
        @scanner = StringScanner.new('')
        next!
      end

      attr_reader :next_lines

      def colno
        @scanner&.pos || 0
      end

      def matched
        @matched ||= @scanner&.matched
      end

      # check which works only once
      def eat_matched?(str)
        return false unless matched == str

        @matched = 'DUMMY'
        true
      end

      def rest
        @rest ||= @scanner&.rest
      end

      alias_method :current, :rest

      # lines navigation
      def next!
        shift(+1)
      end

      def prev!
        shift(-1)
      end

      def eof?
        !next_lines || # we are after the file end
          next_lines.empty? && eol?
      end

      def inspect
        "#<Context(line #{lineno} of #{@lines.count}: #{current})>"
      end

      # scanning
      def scan(re)
        res = @scanner.scan(re)
        @matched = nil
        @rest = nil
        res
      end

      def check(re)
        res = @scanner.check(re)
        @matched = nil
        @rest = nil
        res
      end

      def skip(re)
        res = @scanner.skip(re)
        @matched = nil
        @rest = nil
        res
      end

      def scan_until(re, leave_pattern = false)
        guard_eof!

        res = _scan_until(re)
        res[matched] = '' if res && !leave_pattern
        res
      end

      def push_eol_sign(re)
        @inline_eol_sign = re
      end

      def pop_eol_sign
        @inline_eol_sign = nil
      end

      attr_reader :inline_eol_sign

      def inline_eol?(exclude = nil)
        # not using StringScanner#check, as it will change #matched value
        eol? ||
          (
            (current =~ %r[^(</ref>|}})] || @inline_eol_sign && current =~ @inline_eol_sign) &&
            (!exclude || Regexp.last_match(1) !~ exclude)
          ) # FIXME: ugly, but no idea of prettier solution
      end

      def scan_continued_until(re, leave_pattern = false)
        res = +''

        loop do
          chunk = _scan_until(re)
          case matched
          when re
            res << chunk
            break
          when nil
            res << rest << "\n"
            next!
            eof? && fail!("Unfinished scan: #{re} not found")
          end
        end

        res[/#{re}\Z/] = '' unless leave_pattern
        res
      end

      # state inspection
      def matched_inline?(re)
        if re.nil?
          matched.empty? && eol?
        elsif re.inspect.start_with?('/^') # was it REALLY at the beginning of the line?..
          @scanner.pos == matched.length && matched =~ re
        else
          matched =~ re
        end
      end

      def matched?(re)
        re && matched =~ re
      end

      def eol?
        !current || current.empty?
      end

      # basic services
      def fail!(text)
        fail(ParsingError, "#{text} at line #{@lineno}:\n\t#{current}")
      end

      def unscan_matched!
        return unless @matched

        @scanner.pos -= @matched.size
        @rest = nil
      end

      private

      # we do hard use of #matched and #rest, its wiser to memoize them
      def _scan_until(re)
        res = @scanner.scan_until(re)
        @matched = nil
        @rest = nil
        res
      end

      def guard_eof!
        @scanner or fail!('End of input reached')
      end

      def shift(amount)
        @lineno += amount
        current = @lines[lineno]
        @next_lines = @lines[(lineno + 1)..]
        if current
          @scanner.string = current
          @rest = current
        else
          @scanner = nil
          @rest = nil
        end
        @matched = nil
      end
    end
  end
end
