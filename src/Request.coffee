querystring = require 'querystring'
inspect     = require('eyes').inspector()

protocols =
	http:  require 'http'
	https: require 'https'

contentTypes =
	json:       'application/json'
	urlencoded: 'application/x-www-form-urlencoded'

class Request
	
	constructor: (@protocol, @host, @port, @cookieJar) ->
		@headers = {'Host': @host}
		@setFormat 'json'
	
	setFormat: (format) ->
		@format = format
		@headers['Accept'] = @headers['Content-Type'] = contentTypes[@format]
	
	setHeader: (name, value) ->
		@headers[name] = value
	
	addData: (line) ->
		if @data? then @data += line else @data = line
	
	execute: (callback) ->
		options =
			host:    @host
			port:    @port
			method:  @method.toUpperCase()
			path:    encodeURI '/' + @path.join('/')
			headers: @headers
		
		unless @cookieJar.isEmpty
			options.headers['Cookie'] = @cookieJar.toHeader()
		
		request = protocols[@protocol].request options, (response) =>
			body = ''
			response.setEncoding('utf8')
			response.on 'data', (chunk) -> body += chunk
			response.on 'end', -> callback(response, body)
		
		request.setTimeout 10000
		request.write(@data) if @data?
		request.end()

module.exports = Request