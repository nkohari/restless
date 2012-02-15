querystring = require 'querystring'
readline    = require 'readline'
colors      = require 'colors'
inspect     = require('eyes').inspector()
_           = require 'underscore'

protocols =
	http:  require 'http'
	https: require 'https'

class RestConsole
	
	constructor: (config) ->
		@protocol = config.protocol ? 'http'
		@host     = config.host     ? 'localhost'
		@port     = config.port     ? 80
		
		@cookies = {}
		@path = []
		@state = 'starting'
		
		@readline  = readline.createInterface(process.stdin, process.stdout)
	
	start: ->
		@readline.on 'line', (line) => @onInput line.trim()
		@readline.on 'close', => @onClose
		
		process.stdin.on 'keypress', (s, key) =>
			if key? and key.ctrl and key.name is 'l'
				@clearScreen()
				
		@state = 'command'
		@showPrompt()
	
	onInput: (line) ->
		if @state is 'command'
			@processCommand line
		else
			if line.length is 0
				@executeRequest @pending
			else
				if @pending.data? then @pending.data += line else @pending.data = line
				@showPrompt()
	
	onClose: ->
		console.log '\nkbye'
		process.exit(0)
	
	processCommand: (line) ->
		[command, args...] = line.split /\s+/
		command = command.toLowerCase()
		
		if command is 'cd'
			path = @_processPath args[0]
			if path is null
				console.log 'invalid path'.yellow
			else
				@path = path
		else if command in ['get', 'put', 'post', 'delete', 'head']
			if args.length is 0
				path = @path
			else
				path = @_processPath args[0]
				if path is null
					console.log 'invalid path'.yellow
					return
			request = {method: command, path: path}
			if command is 'put' or command is 'post'
				@pending = request
				@showPrompt()
			else
				@execute request
			return
		else if command isnt ''
			console.log "unknown command #{command}".yellow
		
		@showPrompt()
	
	execute: (request) ->
		@makeRequest request, (response, body) =>
			@showResponse response, body, =>
				delete @pending
				@showPrompt()
	
	clearScreen: ->
		process.stdout.write '\u001B[2J\u001B[0;0f'
		@showPrompt()
	
	showPrompt: ->
		if @state is 'command'
			site = "#{@protocol}://#{@host}:#{@port}"
			path = " /#{@path.join '/'} "
			end  = '> '
			@readline.setPrompt site.grey + path.white + end.grey, (site + path + end).length
		else
			prompt = 'json | '
			@readline.setPrompt prompt.grey, prompt.length
		@readline.prompt()
	
	makeRequest: (spec, callback) ->
		options =
			host:   @host
			port:   @port
			method: spec.method.toUpperCase()
			path:   encodeURI '/' + spec.path.join('/')
			
		options.headers = _.extend {}, options.headers,
			'Host':         @host
			'Accept':       'application/json'
			'Content-Type': 'application/json'
			
		request = protocols[@protocol].request options, (response) =>
			for name, cookie of @_getCookies(response)
				@cookies[name] = cookie
			body = ''
			response.setEncoding('utf8')
			response.on 'data', (chunk) -> body += chunk
			response.on 'end', -> callback(response, body)
		
		@_setCookies(request)
		
		request.setTimeout 10000
		request.write(spec.data) if spec.data?
		request.end()
	
	showResponse: (response, body, callback) ->
		status = "HTTP/#{response.httpVersion} #{response.statusCode} #{protocols.http.STATUS_CODES[response.statusCode]}"
		
		if      response.statusCode >= 500 then status = status.red
		else if response.statusCode >= 400 then status = status.yellow
		else if response.statusCode >= 300 then status = status.cyan
		else status = status.green
		
		console.log status
		for header in response.headers
			console.log "#{header.white}: #{response.headers[header].grey}"
		
		try
			result = JSON.parse(body)
		catch ex
			result = body.trim()
		
		if _.isString(result)
			console.log result.white
		else
			inspect(result)
		
		if process.stdout.write ''
			callback()
		else
			process.stdout.on 'drain', callback
	
	_processPath: (str) ->
		segments = _.filter str.split('/'), (segment) -> segment.length
		if str[0] is '/'
			path = segments
		else
			path = @path.slice(0)
			for segment in segments
				if segment is '..'
					if path.length is 0 then return null
					path.pop()
				else
					path.push segment
		return path
	
	_setCookies: (request) ->
		return unless @cookies.length > 0
		makeHeaderSegment = (cookie) ->
			header = "#{cookie.name}=#{querystring.escape(cookie.value)}"
			op = cookie.options
			if op.path?     then header += "; path=#{op.path}"
			if op.expires?  then header += "; expires=#{op.expires.toUTCString()}"
			if op.domain?   then header += "; domain=#{op.domain}"
			if op.secure?   then header += "; secure"
			if op.httpOnly? then header += "; httpOnly"
		request.headers['Cookie'] = (makeHeaderSegment cookie for name, cookie in @cookies).join ', '
	
	_getCookies: (response) ->
		headers = response.headers['set-cookie']
		cookies = {}
		
		if headers?
			for header in headers
				pairs  = header.split /; */
				tokens = pairs.shift().match(/^(.+?)=(.*)$/).slice(1)
				cookie =
					name:    tokens[0]
					value:   querystring.unescape tokens[1]
					options: {}
				for pair in pairs
					[name, value] = token.split '='
					cookie.options[name] = value ? true
					if name is 'expires' then cookie.options.expires = new Date(cookie.options.expires)
				cookies[cookie.name] = cookie
		
		return cookies
	
module.exports = RestConsole