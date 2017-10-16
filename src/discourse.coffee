try
  {Robot,Adapter,TextMessage,User} = require 'hubot'
catch
  prequire = require('parent-require')
  {Robot,Adapter,TextMessage,User} = prequire 'hubot'

messageBus = require './message-bus.js'
os = require 'os'
url = require 'url'
request = require 'request'
{EventEmitter} = require 'events'

class Discourse extends Adapter

  constructor: ->
    super
    @robot.logger.info "Constructor"

  send: (envelope, strings...) ->
    message = strings.join(os.EOL)
    if typeof envelope.room is 'string'
      pm_envelope =
        message: message
        title: strings[0]
        usernames: envelope.room
      @robot.logger.info "PM", pm_envelope
      @bot.pm pm_envelope
    else if envelope.pm && !envelope.message.pm
      pm_envelope =
        message: envelope.message.slug + os.EOL + message
        title: "About your post in #{envelope.message.title}"
        usernames: envelope.user.username
      @robot.logger.info "PM", pm_envelope
      @bot.pm pm_envelope
    else if typeof envelope.message.id is 'number' && typeof envelope.room is 'number'
      reply_envelope =
        topic_id: envelope.room
        reply_to_post_number: envelope.message.id
        message: message
      @robot.logger.info "Reply", reply_envelope
      @bot.reply reply_envelope
    else if typeof envelope.room is 'number'
      send_envelope =
        topic_id: envelope.room
        message: message
      @robot.logger.info "Send", send_envelope
      @bot.post send_envelope

  reply: (envelope, strings...) ->
    strings[0] = "@#{envelope.user.username} #{strings[0]}"
    @send envelope, strings...

  run: ->
    self = @
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
      (post_id, topic_id, post_number, username, raw, pm, slug, title) ->
        bot.getUser username, (user) ->
          user.room = topic_id
          message = new TextMessage user, raw, post_number
          message.pm = pm
          message.title = title
          message.slug = slug
          self.robot.receive message
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
    @alertChannel @username, (channel) ->
      messageBus.bus.apiKey = self.key
      messageBus.bus.baseUrl = self.server + "/"
      messageBus.bus.subscribe channel, (notification) ->
        self.handleNotification notification

  handleNotification: (notification) ->
    self = @
    @robot.logger.info "got notification: ", notification
    @getPost notification, (data) ->
      #self.robot.logger.info "post data: ", data
      # pretend like private messages are like mentions
      message = data.raw
      pm = false
      if [6].indexOf(notification.notification_type) >= 0
        message = "#{self.robot.name} " + data.raw
        pm = true
      self.emit "message", data.id, data.topic_id, data.post_number, data.username, message, pm, self.server + notification.post_url, notification.topic_title

  alertChannel: (username, callback) ->
    self = @
    if @userId
      callback "/notification-alert/#{@userId}"
    else
      @getUser username, (user) ->
        self.userId = user.id
        self.alertChannel username, callback

  getPost: (notification, callback) ->
    self = @
    request.get "#{@server}/posts/by_number/#{notification.topic_id}/#{notification.post_number}.json?api_key=#{@key}",
    {json: true}, (err, response, data) ->
      if err
        self.robot.logger.error "error when getting post: ", err
      else
        callback data

  getUser: (username, callback) ->
    self = @
    request.get "#{@server}/users/#{username}.json?api_key=#{@key}",
    {json: true}, (err, response, data) ->
      if err
        self.robot.logger.error "error when getting user: ", err
      else
        user = self.robot.brain.userForId username, data.user
        callback user

  reply: ({message, topic_id, reply_to_post_number}) ->
    self = @
    target = "#{@server}/posts.json"
    request.post target, {form: {api_key: @key, topic_id: topic_id, reply_to_post_number: reply_to_post_number, raw: message}, json: true},
      (err, response, body) ->

  post: ({message, topic_id}) ->
    self = @
    target = "#{@server}/posts.json"
    request.post target, {form: {api_key: @key, topic_id: topic_id, raw: message}, json: true},
      (err, response, body) ->

  pm: ({message, title, usernames}) ->
    self = @
    target = "#{@server}/posts.json"
    request.post target, {form: {api_key: @key, title: title, target_usernames: usernames, raw: message, archetype: "private_message"}, json: true},
      (err, response, body) ->
