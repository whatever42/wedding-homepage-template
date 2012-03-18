#!/usr/bin/ruby

class String

  # older ruby versions do not support this convenience shortcut
  def each_char
    if block_given?
      scan(/./m) do |x|
        yield x
      end
    else
      scan(/./m)
    end
  end

end



