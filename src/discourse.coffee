try
  {Robot,Adapter,TextMessage,User} = require 'hubot'
catch
  prequire = require('parent-require')
  {Robot,Adapter,TextMessage,User} = prequire 'hubot'

https = require 'https'
moment = require 'moment';
{EventEmitter} = require 'events'

class Discourse extends Adapter

  constructor: ->
    super
    @robot.logger.info "Constructor"

  send: (envelope, strings...) ->
    @robot.logger.info "Send", envelope, strings

  reply: (envelope, strings...) ->
    @robot.logger.info "Reply", envelope, strings

  run: ->
    @robot.logger.info "Run"
    options =
      username: process.env.HUBOT_DISCOURSE_USERNAME
      key:   process.env.HUBOT_DISCOURSE_KEY
      server:   process.env.HUBOT_DISCOURSE_SERVER
    bot = new DiscoursePoller(options, @robot)
    bot.listen()
    @emit "connected"
    user = new User 1001, name: 'Sample User'
    message = new TextMessage user, '@hubot-test open the pod bay doors', 'MSG-001'
    @robot.receive message
    @bot = bot


exports.use = (robot) ->
  new Discourse robot

class DiscoursePoller extends EventEmitter
  constructor: (options, @robot) ->
    unless options.username? and options.key? and options.server?
      @robot.logger.error \
        "Not enough parameters provided. I need a username, key, and server"
      process.exit(1)

    @username = options.username
    @key = options.key
    @server = options.server.replace(/\/$/, "")

  listen: ->
    self = @
    https.get self.server + "/notifications.json?api_key=" + self.key + "&username=" + self.username + "&recent=true&silent=true&limit=10", (res) ->
      data = ''
      res.on 'data', (chunk) ->
        data += chunk.toString()
      res.on 'end', () ->
        data = JSON.parse(data)
        notifications = data.notifications.filter (notification) ->
          moment(notification.created_at).isAfter(moment().subtract(10, "seconds")) &&
          #notification types enum https://github.com/discourse/discourse/blob/master/app/models/notification.rb
          [1, 2, 6, 15].indexOf(notification.notification_type) >= 0
        self.robot.logger.info "filtered notifications: ", notifications
        self.emit "message"
        setTimeout ->
          self.listen()
        , 10000
