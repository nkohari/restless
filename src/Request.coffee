querystring = require 'querystring'

protocols =
	http:  require 'http'
	https: require 'https'

contentTypes =
	json:       'application/json'
	urlencoded: 'application/x-www-form-urlencoded'
	xml:        'application/xml'

class Request
	
	constructor: (@protocol, @host, @port, @cookieJar, headers = {}) ->
		@headers = _.extend headers, 
			'Host': @host
		@setFormat 'json'
		
		@data = ""
	
	setFormat: (format) ->
		@format = format
		@headers['Accept'] = @headers['Content-Type'] = contentTypes[@format]
	
	setHeader: (name, value) ->
		@headers[name] = value
	
	addData: (line) ->
		@data += line
	
	execute: (callback) ->
		@headers['content-length'] = Buffer.byteLength @data, 'utf8'
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