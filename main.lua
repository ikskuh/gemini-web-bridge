-- Lua 5.1 compatibility:
if _VERSION == "Lua 5.1" then
	function table.pack(a, ...)
		if not a then
			return { }
		else
			local t = table.pack(...)
			table.insert(t, 1, a)
			return t
		end
	end

	function table.unpack(t, n)
		n = n or 1
		if n > #t then
			return
		end
		if n == #t then
			return t[n]
		else
			return t[n], table.unpack(t, n + 1)
		end
	end
end

local sleep = require "socket".sleep
local http_server = require "http.server"
local http_headers = require "http.headers"

local cfg = dofile("config.lua")

if not cfg then
	print("Failed to initialize gemini bridge: no config.lua present!")
	return
end

print("Loading http handler")
dofile("http.lua")

print("Starting HTTP server")
HTTP = assert(http_server.listen {
	host = cfg.http_server or "localhost";
	port = cfg.http_port or 8080;
	onstream = function(myserver, stream)
		HTTP_reply(myserver, stream, cfg)
	end;
	onerror = function(myserver, context, op, err, errno) -- luacheck: ignore 212
		local msg = op .. " on " .. tostring(context) .. " failed"
		if err then
			msg = msg .. ": " .. tostring(err)
		end
		assert(io.stderr:write(msg, "\n"))
	end;
})

-- Manually call :listen() so that we are bound before calling :localname()
assert(HTTP:listen())
do
	local bound_port = select(3, HTTP:localname())
	assert(io.stderr:write(string.format("Now listening on port %d\n", bound_port)))
end

print("Ready")

while not QUIT do
	HTTP:step(0.01)
	sleep(0.01)
end
