querystring = require 'querystring'

class Cookie
	
	constructor: (@name, @value, @options = {}) ->
		expires = @options.expires
		if expires? and _.isString(expires)
			@options.expires = new Date(expires)
	
	toHeader: ->
		header = "#{@name}=#{querystring.escape(@value)}"
		if @options.path?     then header += "; path=#{@options.path}"
		if @options.expires?  then header += "; expires=#{@options.expires.toUTCString()}"
		if @options.domain?   then header += "; domain=#{@options.domain}"
		if @options.secure?   then header += "; secure"
		if @options.httpOnly? then header += "; httpOnly"
		return header
	
module.exports = Cookie