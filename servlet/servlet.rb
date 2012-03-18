#!/usr/bin/ruby

require 'webrick'
require 'src/webserver_servlet'

require 'lib-website/template'
require 'lib-website/auth'
require 'lib-website/session'

require 'file_storage'

class AuthenticationError < RuntimeError
end

class WeddingServlet < WebServerServlet

	include Template

	LOGIN_TEMPLATE_FILE = 'login.template'
	MAIN_PAGE_TEMPLATE_FILE = 'main.template'
	PAGES_DIR = 'pages'
	VERSION_FILE = 'version'
	DEFAULT_VERSION_INFO = {
		:version => "dev",
		:last_updated => "unknown"
	}
	@@passwords_file = 'passwords.yaml'

	MENU = [
		{:id => "default", :title => "Info", :template => "default.template"},
		{:id => "schedule", :title => "Ablauf", :template => "schedule.template"},
		{:id => "location", :title => "Anfahrt", :template => "location.template"},
		{:id => "gallery", :title => "Gallerie", :template => "gallery.template", :type => :gallery },
		{:id => "organization", :title => "Organisation", :template => "organization.template"},
		{:id => "upload", :template => "upload.template", :type => :upload },
		]

	@@path = servlet_path
	PICTURES_METADATA_FILENAME = "gallery.metadata.yaml"
	GALLERY_IMAGE_PATH = "images"
	PICTURES_PER_PAGE = 25
	PICTURES_PER_ROW = 5
	PICTURES_PATH = "/gallery"

	DEFAULT_UPLOAD_PATH = "upload"
	DEFAULT_UPLOAD_SPACE = 1024 * 1024  # 1 Mb
	MAX_NUM_FILES = 16
	DEFAULT_NOTIFICATION_INTERVAL = 60 * 60  # 1h
	DEFAULT_NOTIFICATION_MAILSERVER = nil
	DEFAULT_NOTIFICATION_EMAIL = nil

	def self.read_version_info(filename)
		if File.exists?(filename)
			eval(File.read(filename))
		else
			DEFAULT_VERSION_INFO
		end
	end

	@@authentication = Authentication.new("#{@@path}/#{@@passwords_file}", false)
	@@sessions = Session.new
	@@version_info = read_version_info("#{@@path}/#{VERSION_FILE}")
	@@filestorage = nil

	def initialize(server, *options)
		super(server, *options)
		@server_info = @options[0]
		@config = @options[1]
		@gallery_path = @config[:gallery_path]
		filename = "#{@gallery_path}/#{PICTURES_METADATA_FILENAME}"
		@pictures = YAML::load(File.read(filename)) unless @pictures
		unless @gallery_servlet
			@gallery_servlet = WEBrick::HTTPServlet::FileHandler.get_instance(@server, "#{@gallery_path}/#{GALLERY_IMAGE_PATH}", :FancyIndexing => true)
		end
		unless @static_servlet
			@static_servlet = WEBrick::HTTPServlet::FileHandler.get_instance(@server, "#{@@path}/static", :FancyIndexing => true)
		end
	end

	def do_GET(req, resp)
		@@filestorage = FileStorage.new(@config[:upload_path] || "#{@@path}/#{DEFAULT_UPLOAD_PATH}",
						@config[:upload_space] || DEFAULT_UPLOAD_SPACE,
						@logger,
						@config[:notification_interval] || DEFAULT_NOTIFICATION_INTERVAL,
						@config[:notification_mailserver] || DEFAULT_NOTIFICATION_MAILSERVER,
						@config[:notification_email] || DEFAULT_NOTIFICATION_EMAIL) unless @@filestorage
		@root_dir = @@path
		case req.path
		when "/page"
			begin
				build_main_page(req, resp)
			rescue AuthenticationError => e
				build_login_page(req, resp, e.message)
			end
		when /^\/gallery/
			# pass only remaining path
			req.path_info = $'
			@gallery_servlet.do_GET(req, resp)
		when /^\/static/
			# pass only remaining path
			req.path_info = $'
			@static_servlet.do_GET(req, resp)
		else
			build_login_page(req, resp)
		end
	end

	alias do_POST do_GET

	def build_login_page(req, resp, message = "")
		username = req.query['username']
		if username and username =~ /^[a-zA-Z]*$/
			username_code = "value=\"#{username}\""
		else
			username_code = "value=\"username\" onfocus=\"this.form.username.value=''\""
		end
		resp.body = use_template("#{@root_dir}/#{LOGIN_TEMPLATE_FILE}", { "[MSG]" => message, "[USERNAME]" => username_code })
	end

	def access_control(req, resp)
		session = nil
		session_id = nil
		
		username = req.query['username']
		password = req.query['password']
		if username and password
			session = @@authentication.authenticate(username, password)
			unless session
				@logger.info("invalid login attempt from #{req.peeraddr[3]}")
				raise AuthenticationError.new("invalid username or password")
			end
			session[:username] = username
			session_id = @@sessions.create_new(session)
			@logger.info("user #{session[:name]} logged in. session_id=#{session_id}")
		else
			session_id, session = @@sessions.get_session_from_cookies(req)
			raise AuthenticationError.new("session expired") unless session
		end

		@@sessions.add_session_cookie(resp, session_id)
		return session, session_id
	end

	def build_menu(req)
		page = get_page(req)
		res = ""
		MENU.each do |item|
			next unless item[:title]
			link = item[:link] || "/page?page=#{item[:id]}"
			res += "<a class=\"#{ item == page ? "item_selected" : "item" }\" href=\"#{link}\">#{item[:title]}</a>"
		end
		return res
	end

	def build_gallery_row(pics, base_index, row_base_index, section_index, subsection_index)
		pics.zip((0..pics.size-1).to_a).map{ |pic, index| "<td><a href='/page?page=gallery&img_id=#{base_index + row_base_index + index}&section=#{section_index}&subsection=#{subsection_index}#gallery'><img src='#{PICTURES_PATH}/#{pic[:thumb]}'></a></td>" }.join("")
	end

	def build_gallery(req)
		res = ""
		@pictures.each_with_index do |section, index|
			res += build_gallery_section(req, section, index)
		end
		return res
	end

	def build_gallery_section(req, section, index)
		res = "<div class='gallery_section'><div class='gallery_section_title'>~ #{section[:name]} ~</div>"
		section[:subsections].each_with_index do |subsection, subindex|
			res += build_gallery_subsection(req, subsection, index, subindex)
		end
		res += "</div>"
		return res
	end

	def build_gallery_subsection(req, subsection, index, subindex)
		res = "<div class='gallery_subsection'><div class='gallery_subsection_title'>#{subsection[:name]}</div>"
		res += build_picture_gallery(req, subsection[:pics], index, subindex)
		res += "</div>"
		return res
	end

	def build_picture_gallery(req, pictures, index, subindex)
		section_param = req.query["section"]
		subsection_param = req.query["subsection"]
		section_index = section_param ? Integer(section_param) : -1
		subsection_index = subsection_param ? Integer(subsection_param) : -1
		if index == section_index and subindex == subsection_index
			return build_full_picture_gallery(req, pictures, index, subindex)
		else
			return build_preview_picture_gallery(req, pictures, index, subindex)
		end
	end

	def build_preview_picture_gallery(req, pictures, index, subindex)
		pics = pictures[0, PICTURES_PER_ROW]
		res = "<div class='gallery_pictures_preview'>"
		res += "<table class='gallery_pictures_table'><tr>"
		res += build_gallery_row(pics, 0, 0, index, subindex)
		res += "<td><a href='/page?page=gallery&page_index=0&section=#{index}&subsection=#{subindex}#gallery'><div>...</div></td>" if pictures.size > pics.size
		res += "</tr></table>"
		if pictures.size > pics.size
			res += "(#{pictures.size} pictures)"
		end
		res += "</div>"
		return res
	end

	def build_full_picture_gallery(req, pictures, gindex, subindex)
		pics = pictures
		base_index = 0
		page_index = 0
		img_id = nil
		begin
			img_id = Integer(req.query["img_id"]) if req.query["img_id"]
		rescue
			# noop
		end
		if img_id
			page_index = img_id / PICTURES_PER_PAGE
		else
			begin
				page_index = Integer(req.query['page_index'])
			rescue
				# noop
			end
		end
		if pictures.size > PICTURES_PER_PAGE
			base_index = page_index * PICTURES_PER_PAGE
			pics = pictures[base_index, PICTURES_PER_PAGE]
		end
		return "" unless pics

		res = "<div class='gallery_pictures' id='gallery'>"
		if img_id and (0..pictures.size-1).include?(img_id)
			pic = pictures[img_id]
			res += "<div class='gallery_main_image_space'>"
			res += "<div class='gallery_main_image_previous'><a href='/page?page=gallery&img_id=#{img_id-1}&section=#{gindex}&subsection=#{subindex}#gallery'>&lt;&lt;</a></div>" if img_id > 0
			res += "<div class='gallery_main_image_next'><a href='/page?page=gallery&img_id=#{img_id+1}&section=#{gindex}&subsection=#{subindex}#gallery'>&gt;&gt;</a></div>" if img_id < pictures.size-1
			res += "<div class='gallery_main_image'><img src='#{PICTURES_PATH}/#{pic[:src]}'></div>"
			res += "</div>"
		end
		res += "<table class='gallery_pictures_table'>"
		row_base_index = 0
		while pics and !pics.empty?
			row_pics = pics[0, PICTURES_PER_ROW]
			pics = pics[PICTURES_PER_ROW, pics.size]
			res += "<tr>#{build_gallery_row(row_pics, base_index, row_base_index, gindex, subindex)}</tr>"
			row_base_index += PICTURES_PER_ROW
		end
		res += "</table>"
		if pictures.size > PICTURES_PER_PAGE
			num_pages = (pictures.size.to_f / PICTURES_PER_PAGE.to_f).ceil
			res += "<div class='gallery_page_selection'>"
			res += "&lt;" + (0..num_pages-1).map { |i|
				if page_index == i
					"(#{i+1})"
				else
					"<a href='/page?page=gallery&page_index=#{i}&section=#{gindex}&subsection=#{subindex}#gallery'>#{i+1}</a>"
				end
			}.join(",") + "&gt;"
			res += "</div>"
		end
		res += "</div>"
	end

	def get_page(req)
		pageId = req.query['page'] || "default"
		MENU.each do |item|
			return item if item[:id] == pageId
		end
		raise RuntimeError.new("unknown page")
	end

	def make_human_readable(size)
		if size < 1024 * 1024
			size_in_kb = size / 1024.0
			size_in_kb = size_in_kb.round
			return "#{size_in_kb.to_s} kB"
		end
		if size < 1024 * 1024 * 1024
			size_in_mb = size / (1024.0 * 1024.0)
			size_in_mb = (size_in_mb * 10.0).round / 10.0
			return "#{(size_in_mb).to_s} MB"
		end
		size_in_gb = size / (1024.0 * 1024.0 * 1024.0)
		size_in_gb = (size_in_gb * 100.0).round / 100.0
		return "#{size_in_gb.to_s} GB"
	end

	def build_files_display(username)
		res = ""
		list = @@filestorage.list(username)
		unless list.empty?
			res += "Folgende Dateien wurden hochgeladen:"
			res += "<table width='100%' class='filelist'>"
			list.each do |filename|
				res += "<tr><td>#{filename}</td><td width='10%'><a href='page?page=upload&action=delete&filename=#{URI.escape(filename)}'>delete</a></td></tr>"
			end
			res += "</table>"
		end
		return res
	end

	def build_diskspace_display()
		used = @@filestorage.used()
		size = @@filestorage.size()
		bar_width = 100.0
		val = bar_width * (used.to_f / size.to_f)
		res = "<table width='#{bar_width.round()}%' class='diskspace'><tr><td width='#{val.round()}%' class='diskspace_bar'></td><td width='#{(bar_width - val).round()}%' class='diskspace_space'></td></tr></table>"
		res += "diskspace: #{make_human_readable(used)} / #{make_human_readable(size)}"
		return res
	end

	def build_upload_bar(req)
		res = "<form class='upload_form' action='page' method='post' enctype='multipart/form-data'>\n"
		res += "  <input name='page' value='upload' type='hidden'>\n"
		num_files = req.query["num_files"] || 1
		begin
			num_files = Integer(num_files)
		rescue
			num_files = 1
		end
		num_files = 1 if num_files < 1
		num_files = MAX_NUM_FILES if num_files > MAX_NUM_FILES
		num_files.times do |i|
			res += "  <input name='file#{i}' type='file' size='40'>\n"
		end
		res += "  <div class='upload_form_buttons'>\n"
		if num_files < MAX_NUM_FILES
			res += "    <a class='more_files_button' href='page?page=upload&num_files=#{num_files * 2}'>mehr Dateien...</a>\n"
		end
		res += "    <input name='Hochladen' type='submit' value='Hochladen'>\n"
		res += "  </div>"
		res += "</form>"
		return res
	end

	def build_content(req, session)
		page = get_page(req)
		template = "#{@root_dir}/#{PAGES_DIR}/#{page[:template]}"
		if page[:type] == :gallery
			return use_template(template, {
				"[GALLERY]" => build_gallery(req)
			} )
		elsif page[:type] == :upload
			if req.request_method == "POST"
				MAX_NUM_FILES.times do |i|
					file_contents = req.query["file#{i}"]
					next unless file_contents
					filename = nil
					req.body.split("\n").each do |line|
						filename = $1 if line =~ /Content-Disposition: form-data; name=\"file#{i}\"; filename=\"(.*)\"/
					end
					raise RuntimeError.new("filename of file#{i} could not be determined") unless filename
					@@filestorage.store(session[:username], filename, file_contents)
				end
			else
				filename = req.query["filename"]
				if req.query["action"] == "delete" and filename
					@@filestorage.remove(session[:username], filename)
				end
			end
			return use_template(template, {
				"[DISKSPACE]" => build_diskspace_display(),
				"[FILELIST]" => build_files_display(session[:username]),
				"[UPLOAD-BAR]" => build_upload_bar(req)
			} )
		else
			return use_template(template)
		end
	end

	def build_main_page(req, resp)
		session, session_id = access_control(req, resp)
		resp['content-type'] = 'text/html;charset=utf-8'
		resp.body = use_template("#{@root_dir}/#{MAIN_PAGE_TEMPLATE_FILE}", {
			"[NAME]" => session[:name],
			"[VERSION]" => @@version_info[:version].to_s,
			"[LAST_UPDATED]" => @@version_info[:last_updated].to_s,
			"[MENU]" => build_menu(req),
			"[CONTENT]" => build_content(req, session)
		} )
	end

	def self.version
		@@version_info[:version]
	end

end

{
	:name => "wedding",
	:version => WeddingServlet.version,
	:servlet => WeddingServlet
}

