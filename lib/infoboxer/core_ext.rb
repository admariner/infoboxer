# frozen_string_literal: true

# @private
class Object
  # Unfortunately, not in backports gem still :(
  if RUBY_VERSION < '2.2.0'
    def itself
      self
    end
  end
end
