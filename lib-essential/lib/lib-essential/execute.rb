
class ProcessInfo

	attr_accessor :pid

	def initialize
		@pid = nil
	end

end

module Kernel

	DEFAULT_BLOCKSIZE = 1024

	# Runs a command in a subprocess as specified by the given hash. The following parameters can be given this way:
	#     :cmd => Array holding the command and it's arguments. The first item is subject to shell expansion, the others
	#             are not. A command can thus be passed as a single String in an array if expansion is desired or as
	#             multiple Strings in an Array otherwise.
	#     :allow_exitcodes => Array holding all exitcodes allowed for this subsommand. If the subprocess exits with an
	#                         exitcode not in this list, a RuntimeError is raised. If nil is passed, the exitcode of
	#                         the subprocess is ignored.
	#     :stdout => specifies what to do with output going to stdout. Possible values are
	#                :return  - after termination of the subprocess, return its entire output to stdout as a String.
	#                :drop    - just drop everything the subprocess outputs to stdout.
	#                nil      - let the subprocess use our stdout for output.
	#     :stderr => specifies what to do with output going to stderr. Possible values are
	#                :return  - after termination of the subprocess, return its entire output to stderr as a String.
	#                :drop    - just drop everything the subprocess outputs to stderr.
	#                nil      - let the subprocess use our stderr for output.
	# Returns when the subprocess has terminated.
	def run_sub_cmd(hash = {}, &block)
		stdout_content, stderr_content = "", ""
		rd_stdout, rd_stderr = nil, nil
		sub_stdout, sub_stderr = nil, nil
		close_sub_stdout, close_sub_stderr = true, true

		cmd = hash[:cmd]
		unless cmd
			raise RuntimeError.new("neither command nor block to execute") unless block or hash[:proc]
			hash[:proc] = block if block
		end
		if hash[:stdout] == :return
			rd_stdout, sub_stdout = IO.pipe
		elsif hash[:stdout] == :drop
			sub_stdout = File.new("/dev/null", "w")
		elsif hash[:stdout]
			sub_stdout = hash[:stdout]
			close_sub_stdout = false
		end
		if hash[:stderr] == :return
			rd_stderr, sub_stderr = IO.pipe
		elsif hash[:stderr] == :drop
			sub_stderr = File.new("/dev/null", "w")
		elsif hash[:stderr]
			sub_stderr = hash[:stderr]
			close_sub_stderr = false
		end

		child_pid = fork()
		if child_pid
			# parent process
			sub_stdout.close() if sub_stdout and close_sub_stdout
			sub_stderr.close() if sub_stderr and close_sub_stderr
			hash[:info].pid = child_pid if hash[:info]
			has_stopped = false
			while !has_stopped
				pid, status = Process.wait2(child_pid, Process::WNOHANG)
				has_stopped = status ? status.exited? : false
				if rd_stdout and !rd_stdout.eof?
					res = rd_stdout.read_nonblock(DEFAULT_BLOCKSIZE)
					stdout_content += res if res
				end
				if rd_stderr and !rd_stderr.eof?
					res = rd_stderr.read_nonblock(DEFAULT_BLOCKSIZE)
					stderr_content += res if res
				end
			end
			if hash[:allow_exitcodes]
				raise RuntimeError.new("command failed with exitcode #{$?.exitstatus} in directory #{Dir.pwd()}: #{cmd.join(' ')}") unless hash[:allow_exitcodes].include?($?.exitstatus)
			end
			res = []
			res << stdout_content if hash[:stdout] == :return
			res << stderr_content if hash[:stderr] == :return
			rd_stdout.close() if rd_stdout
			rd_stderr.close() if rd_stderr
			return *res
		else
			# child process
			rd_stdout.close() if rd_stdout
			rd_stderr.close() if rd_stderr
			$stdout.reopen(sub_stdout) if sub_stdout
			$stderr.reopen(sub_stderr) if sub_stderr
			exec *cmd if cmd
			block.call
			exit
		end
	end

end

