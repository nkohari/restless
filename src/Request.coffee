querystring = require 'querystring'
_           = require 'underscore'

protocols =
	http:  require 'http'
	https: require 'https'

Cookie = require './Cookie'

class Request
	
	constructor: (@protocol, @host, @port) ->
		@cookies = {}
		@headers =
			'Host': @host
	
	setCookie: (name, value, options) ->
		@cookies[name] = new Cookie(name, value, options)
	
	addData: (line) ->
		if @data?
			@data += line
		else
			@data = line
	
	execute: (callback) ->
		options =
			host:    @host
			port:    @port
			method:  @method.toUpperCase()
			path:    encodeURI '/' + @path.join('/')
			headers: @headers
		
		# TODO
		options.headers = _.extend options.headers,
			'Accept':       'application/json'
			'Content-Type': 'application/json'
		
		if _.keys(@cookies).length > 0
			options.headers['Cookie'] = (cookie.toHeader() for name, cookie in @cookies).join ', '
			
		request = protocols[@protocol].request options, (response) =>
			cookies = @_getCookiesFromResponse(response)
			body = ''
			response.setEncoding('utf8')
			response.on 'data', (chunk) -> body += chunk
			response.on 'end', -> callback(response, body, cookies)
		
		request.setTimeout 10000
		request.write(@data) if @data?
		request.end()

	_getCookiesFromResponse: (response) ->
		headers = response.headers['set-cookie']
		cookies = {}
		
		if headers?
			for header in headers
				pairs  = header.split /; */
				tokens = pairs.shift().match(/^(.+?)=(.*)$/).slice(1)
				cookie = new Cookie tokens[0], querystring.unescape tokens[1]
				for pair in pairs
					[name, value] = pair.split '='
					if name is 'expires' then value = new Date(value)
					cookie.options[name] = value ? true
				cookies[cookie.name] = cookie
		
		return cookies

module.exports = Request