#!/usr/bin/ruby

class Array

	def each_combination(num, &block)
		if num < 1
			block.call()
			return
		end
		each do |v|
			each_combination(num-1) do |*arr|
				block.call(*(arr + [v]))
			end
		end
	end

	def combinations(num)
		result = []
		each_combination(num) do |*value|
			result << value
		end
		return result
	end

	def each_subset(subset_size, &block)
		return if subset_size > size
		return if subset_size <= 0
		if subset_size == 1
			each do |item|
				block.call([item])
			end
			return
		end
		head = slice(0)
		tail = slice(1,size)
		tail.each_subset(subset_size - 1) do |subset|
			block.call([head] + subset)
		end
		tail.each_subset(subset_size, &block)
	end

	def subsets(subset_size)
		result = []
		each_subset(subset_size) do |value|
			result << value
		end
		return result
	end

end
