local http_headers = require "http.headers"
local http_util = require "http.util"

local function slurp(file)
	local f = assert(io.open(file, "r"))
	if not f then return nil end
	local c = f:read("*all")
	f:close()
	return c
end

local function translate_gemini(source, printer)

	local pre = false
	local in_list = false

	local function closeList()
		if in_list then
			printer("</ul>\n")
			in_list = false
		end
	end

	for line in source:gsub("\r", ""):gmatch("[^\n]*") do
		local f3 = line:sub(1,3)

		if pre then

			if f3 == "```" then
				pre = false
				printer("</pre>\n")
			else
				printer(line .. "\n")
				-- printer("<br />\n")
			end

		else
			if f3 == "```" then
				closeList()
				pre = true
				printer("<pre>")
			elseif f3 == "###" then
				closeList()
				printer("<h3>" .. line:sub(4) .. "</h3>\n")
			elseif f3:sub(1,2) == "##" then
				closeList()
				printer("<h2>" .. line:sub(3) .. "</h2>\n")
			elseif f3:sub(1,1) == "#" then
				closeList()
				printer("<h1>" .. line:sub(2) .. "</h1>\n")
			elseif f3:sub(1,2) == "=>" then
				closeList()
				local link, rest = line:match("=> *([^ ]+) *(.*)")

				if rest == "" or rest == nil then
					printer("<a href=\"", link, "\">", link, "</a><br />\n")
				else
					printer("<a href=\"", link, "\">", rest, "</a><br />\n")
				end
			elseif f3:sub(1,1) == "*" then
				if not in_list then
					printer("<ul>\n")
				end
				in_list = true
				printer("<li>" .. line:sub(2) .. "</li>\n")
				
			else
				closeList()
				printer(line)
				printer("<br />\n")
			end
		end

	end

end


function getFileExtension(url)
  return url:match("^.+(%..+)$")
end

local file_ext_to_mime = {
	[".gemini"] = "text/html",
	[".html"] = "text/html",
	[".htm"] = "text/html",
	[".css"] = "text/css",
	[".js"] = "text/javascript",
	[".jpg"] = "image/jpeg",
	[".jpeg"] = "image/jpeg",
	[".png"] = "image/png",
	[".mp4"] = "video/mp4",
	[".webm"] = "video/webm",
	[".ogg"] = "audio/ogg",
	[".mp3"] = "audio/mp3",
}

function HTTP_reply(myserver, stream, cfg) -- luacheck: ignore 212
	-- Read in headers
	local req_headers = assert(stream:get_headers())
	local req_method = req_headers:get ":method"
	local req_url = http_util.decodeURIComponent(req_headers:get(":path"))

	-- Build response headers
	local res_headers = http_headers.new()
	res_headers:append(":status", "200")
	if req_method ~= "HEAD" then

		local file_ext = getFileExtension(req_url)
		if file_ext == "" or file_ext == nil then
			file_ext = ".gemini"
		end

		if req_url == "/style.css" then
			res_headers:append("content-type", "text/css")
			-- Send headers to client; end the stream immediately if this was a HEAD request
			assert(stream:write_headers(res_headers, false))
			assert(stream:write_chunk(slurp("style.css"), true))
			return
		end
		if req_url == "/favicon.ico" then
			res_headers:append("content-type", "image/x-icon")
			-- Send headers to client; end the stream immediately if this was a HEAD request
			assert(stream:write_headers(res_headers, false))
			assert(stream:write_chunk(slurp("favicon.ico"), true))
			return
		end

		local webprint = function(...)

			local t = table.pack(...)
			local r = ""
			for i=1,#t do
				r = r .. tostring(t[i])
			end
			assert(stream:write_chunk(r, false))
		end

		res_headers:append("content-type", file_ext_to_mime[file_ext] or "application/octet-stream")
		-- Send headers to client; end the stream immediately if this was a HEAD request
		assert(stream:write_headers(res_headers, req_method == "HEAD"))

		if file_ext == ".gemini" then

			webprint(slurp("html-prefix.htm") .. "\n")

			local file_content 
			if req_url == "/" then
				file_content = slurp(cfg.web_root .. "/index.gemini")
										or slurp(cfg.web_root .. "/index.gmi")
										or slurp(cfg.web_root .. "/index.gem")
			else
				file_content = slurp(cfg.web_root .. "/" .. req_url)
			end

			translate_gemini(file_content, webprint)
			
			webprint(slurp("html-postfix.htm"))
			assert(stream:write_chunk("\n", true))
		else
		
			assert(stream:write_chunk(slurp(cfg.web_root .. "/" .. req_url), true))
			
		end
	end
end
