#!/usr/bin/ruby

module Kernel

  def resolve_resource(name)
    $:.each do |path|
	filename = "#{path}/#{name}"
	return filename if File.exists?(filename)
    end
    raise LoadError.new("unknown resource #{name}")
  end

end
