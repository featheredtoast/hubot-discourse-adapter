try
  {Robot,Adapter,TextMessage,User} = require 'hubot'
catch
  prequire = require('parent-require')
  {Robot,Adapter,TextMessage,User} = prequire 'hubot'

os = require 'os'
https = require 'https'
moment = require 'moment';
{EventEmitter} = require 'events'

class Discourse extends Adapter

  constructor: ->
    super
    @robot.logger.info "Constructor"

  send: (envelope, strings...) ->
    reply_envelope =
      topic_id: envelope.room
      post_number: envelope.message.id
      message: strings.join(os.EOL)
    @robot.logger.info "Send", reply_envelope

  reply: (envelope, strings...) ->
    strings[0] = "@" + envelope.user.id + " " + strings[0]
    @send envelope, strings

  run: ->
    @robot.logger.info "Run"
    options =
      username: process.env.HUBOT_DISCOURSE_USERNAME
      key:   process.env.HUBOT_DISCOURSE_KEY
      server:   process.env.HUBOT_DISCOURSE_SERVER
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
    https.get self.server + "/notifications.json?api_key=" + self.key + "&username=" + self.username + "&recent=true&silent=true&limit=20", (res) ->
      res.setEncoding("utf8")
      data = ''
      res.on 'data', (chunk) ->
        data += chunk.toString()
      res.on 'end', () ->
        data = JSON.parse(data)
        notifications = data.notifications.filter (notification) ->
          moment(notification.created_at).isAfter(moment().subtract(10, "days")) &&
          #notification types enum https://github.com/discourse/discourse/blob/master/app/models/notification.rb
          [1, 2, 6, 15].indexOf(notification.notification_type) >= 0
        #self.robot.logger.info "filtered notifications: ", notifications
        for notification in notifications
          self.getPost notification
        setTimeout ->
          self.listen()
        , 10000

  getPost: (notification) ->
    self = @
    https.get @server + "/posts/" + notification.data.original_post_id + ".json?api_key=" + @key, (res) ->
      res.setEncoding("utf8")
      data = ''
      res.on 'data', (chunk) ->
        data += chunk.toString()
      res.on 'end', () ->
        data = JSON.parse(data)
        #self.robot.logger.info "post data: ", data
        self.emit "message", data.id, data.topic_id, data.post_number, data.username, data.raw

  reply: ({message, topic_id, reply_to_post_number}) ->
    https.request @server "/posts", {
      raw: message
      topic_id: topic_id
      reply_to_post_number: reply_to_post_number
      auto_track: false
    }
