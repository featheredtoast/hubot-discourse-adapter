try
  {Robot,Adapter,TextMessage,User} = require 'hubot'
catch
  prequire = require('parent-require')
  {Robot,Adapter,TextMessage,User} = prequire 'hubot'

os = require 'os'
url = require 'url'
request = require 'request'
{EventEmitter} = require 'events'

class Discourse extends Adapter

  constructor: ->
    super
    @robot.logger.info "Constructor"

  send: (envelope, strings...) ->
    reply_envelope =
      topic_id: envelope.room
      reply_to_post_number: envelope.message.id
      message: strings.join(os.EOL)
    @robot.logger.info "Send", reply_envelope
    @bot.reply reply_envelope

  reply: (envelope, strings...) ->
    strings[0] = "@" + envelope.user.id + " " + strings[0]
    @send envelope, strings

  run: ->
    @robot.logger.info "Run"
    options =
      username: process.env.HUBOT_DISCOURSE_USERNAME
      key:   process.env.HUBOT_DISCOURSE_KEY
      server:   process.env.HUBOT_DISCOURSE_SERVER
    @robot.name = options.username
    bot = new DiscoursePoller(options, @robot)
    bot.listen()
    @emit "connected"
    bot.on "message",
      (post_id, topic_id, post_number, username, raw) ->
        user = new User username, name: username, room: topic_id
        message = new TextMessage user, raw, post_number
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
    request.get self.server + "/notifications.json?api_key=" + self.key,
    {json: true}, (err, response, data) ->
      #self.robot.logger.info data
      notifications = data.notifications.filter (notification) ->
        notification.read == false &&
        #notification types enum https://github.com/discourse/discourse/blob/master/app/models/notification.rb
        [1, 2, 6, 15].indexOf(notification.notification_type) >= 0
      self.robot.logger.info "filtered notifications: ", notifications
      markRead = false
      for notification in notifications
        self.getPost notification
        markRead = true
      if markRead
        self.markNotificationsRead()
      setTimeout ->
        self.listen()
      , 10000

  getPost: (notification) ->
    self = @
    request.get @server + "/posts/" + notification.data.original_post_id + ".json?api_key=" + @key,
    {json: true}, (err, response, data) ->
      #self.robot.logger.info "post data: ", data
      # pretend like private messages are like mentions
      message = data.raw
      if [6].indexOf(notification.notification_type) >= 0
        message = "#{self.robot.name} " + data.raw
      self.emit "message", data.id, data.topic_id, data.post_number, data.username, message

  markNotificationsRead: () ->
    self = @
    request.put @server + "/notifications/read.json?api_key=" + @key,
    {json: true}, (err, response, data) ->
      #self.robot.logger.info "post data mark read: ", data

  reply: ({message, topic_id, reply_to_post_number}) ->
    self = @
    target = @server + "/posts.json"
    request.post target, {form: {api_key: @key, topic_id: topic_id, reply_to_post_number: reply_to_post_number, raw: message, auto_track: false}, json: true},
      (err, response, body) ->
