http     = require 'http'
readline = require 'readline'
colors   = require 'colors'
inspect  = require('eyes').inspector()
_        = require 'underscore'

Request = require './Request'

class RestConsole
	
	constructor: (config) ->
		@protocol = config.protocol ? 'http'
		@host     = config.host     ? 'localhost'
		@port     = config.port     ? 80
		
		@cookies = {}
		@path = []
		
		@readline  = readline.createInterface(process.stdin, process.stdout)
	
	start: ->
		@readline.on 'line', (line) => @onInput line.trim()
		@readline.on 'close', => @exit()
		
		process.stdin.on 'keypress', (s, key) =>
			if key? and key.ctrl and key.name is 'l'
				@clearScreen()
				
		@reset()
		@showPrompt()
	
	onInput: (line) ->
		if @state is 'command'
			@processCommand line
		else
			if line.length is 0
				@executeRequest()
			else
				if @request.data? then @request.data += line else @request.data = line
				@showPrompt()
	
	exit: ->
		console.log '\nkbye'
		process.exit(0)
	
	reset: ->
		@state = 'command'
		@request = new Request(@protocol, @host, @port)
	
	processCommand: (line) ->
		[command, args...] = line.split /\s+/
		command = command.toLowerCase()
		
		if command is 'cd'
			path = @_processPath args[0]
			if path is null
				console.log 'Invalid path'.yellow
			else
				@path = path
		else if command is 'set'
			if args.length is 0
				console.log 'Set what?'.yellow
				return
			what = args[0].toLowerCase()
			if what is 'cookie'
				@cookies[args[0]] = {value: args[1]}
				inspect @cookies
				return
		else if command in ['get', 'put', 'post', 'delete', 'head']
			if args.length is 0
				path = @path
			else
				path = @_processPath args[0]
				if path is null
					console.log 'Invalid path'.yellow
					return
			@request.method = command
			@request.path   = path
			if command is 'put' or command is 'post'
				@state = 'data'
				@showPrompt()
			else
				@executeRequest()
			return
		else if command in ['quit', 'exit']
			@exit()
			return
		else if command isnt ''
			console.log "unknown command #{command}".yellow
		
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
	
	executeRequest: ->
		@request.execute (response, body, cookies) =>
			@cookies = cookies
			@showResponse response, body, =>
				@reset()
				@showPrompt()
	
	showResponse: (response, body, callback) ->
		status = "HTTP/#{response.httpVersion} #{response.statusCode} #{http.STATUS_CODES[response.statusCode]}"
		
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
	
module.exports = RestConsole