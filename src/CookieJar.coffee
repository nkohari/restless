fs          = require 'fs'
querystring = require 'querystring'
inspect     = require('eyes').inspector()

Cookie = require './Cookie'

class CookieJar
	
	constructor: (@file) ->
		@__defineGetter__ 'isEmpty', -> _.keys(@cookies).length is 0
		@cookies = {}
		@load()
	
	load: ->
		try
			for name, obj of JSON.parse fs.readFileSync(@file, 'utf8')
				@cookies[name] = new Cookie(obj.name, obj.value, obj.options)
		catch ex
	
	save: ->
		fs.writeFileSync @file, JSON.stringify(@cookies), 'utf8'
	
	toHeader: ->
		(cookie.toHeader() for name, cookie of @cookies).join ', '
			
	update: (response) ->
		headers = response.headers['set-cookie']
		if headers?
			for header in headers
				pairs  = header.split /; */
				tokens = pairs.shift().match(/^(.+?)=(.*)$/).slice(1)
				cookie = new Cookie tokens[0], querystring.unescape tokens[1]
				for pair in pairs
					[name, value] = pair.split '='
					if name is 'expires' then value = new Date(value)
					cookie.options[name] = value ? true
				@cookies[cookie.name] = cookie
		@save()
	
module.exports = CookieJar