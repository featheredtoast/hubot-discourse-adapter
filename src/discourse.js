/*
 * decaffeinate suggestions:
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
let Adapter, Robot, TextMessage, User;
try {
  ({ Robot, Adapter, TextMessage, User } = require("hubot"));
} catch (error) {
  const prequire = require("parent-require");
  ({ Robot, Adapter, TextMessage, User } = prequire("hubot"));
}

const messageBus = require("./message-bus.js");
const os = require("os");
const url = require("url");
const request = require("request");
const { EventEmitter } = require("events");

class Discourse extends Adapter {
  constructor() {
    super(...arguments);
    this.robot.logger.info("Constructor");
  }

  send(envelope, ...strings) {
    let pm_envelope;
    const message = strings.join(os.EOL);
    if (typeof envelope.room === "string") {
      pm_envelope = {
        message,
        title: strings[0],
        usernames: envelope.room
      };
      this.robot.logger.info("PM", pm_envelope);
      this.bot.pm(pm_envelope);
    } else if (envelope.pm && !envelope.message.pm) {
      pm_envelope = {
        message: envelope.message.slug + os.EOL + message,
        title: `About your post in ${envelope.message.title}`,
        usernames: envelope.user.username
      };
      this.robot.logger.info("PM", pm_envelope);
      this.bot.pm(pm_envelope);
    } else if (
      typeof envelope.message.id === "number" &&
      typeof envelope.room === "number"
    ) {
      const reply_envelope = {
        topic_id: envelope.room,
        reply_to_post_number: envelope.message.id,
        message
      };
      this.robot.logger.info("Reply", reply_envelope);
      this.bot.reply(reply_envelope);
    } else if (typeof envelope.room === "number") {
      const send_envelope = {
        topic_id: envelope.room,
        message
      };
      this.robot.logger.info("Send", send_envelope);
      this.bot.post(send_envelope);
    }
  }

  reply(envelope, ...strings) {
    strings[0] = `@${envelope.user.username} ${strings[0]}`;
    this.send(envelope, ...strings);
  }

  run() {
    const self = this;
    this.robot.logger.info("Run");
    const options = {
      username: process.env.HUBOT_DISCOURSE_USERNAME,
      key: process.env.HUBOT_DISCOURSE_KEY,
      server: process.env.HUBOT_DISCOURSE_SERVER
    };
    this.robot.name = options.username;
    const bot = new DiscoursePoller(options, this.robot);
    bot.listen();
    this.emit("connected");
    bot.on(
      "message",
      (post_id, topic_id, post_number, username, raw, pm, slug, title) =>
        bot.getUser(username, function(user) {
          user.room = topic_id;
          const message = new TextMessage(user, raw, post_number);
          message.pm = pm;
          message.title = title;
          message.slug = slug;
          self.robot.receive(message);
        })
    );
    this.bot = bot;
  }
}

exports.use = robot => new Discourse(robot);

class DiscoursePoller extends EventEmitter {
  constructor(options, robot) {
    super(options, robot);
    this.robot = robot;
    if (!options.username || !options.key || !options.server) {
      this.robot.logger.error(
        "Not enough parameters provided. I need a username, key, and server"
      );
      process.exit(1);
    }

    this.username = options.username;
    this.key = options.key;
    this.server = options.server.replace(/\/$/, "");
  }

  listen() {
    const self = this;
    this.alertChannel(this.username, function(channel) {
      messageBus.bus.apiKey = self.key;
      messageBus.bus.baseUrl = self.server + "/";
      messageBus.bus.subscribe(channel, notification =>
        self.handleNotification(notification)
      );
    });
  }

  handleNotification(notification) {
    const self = this;
    this.robot.logger.info("got notification: ", notification);
    this.getPost(notification, function(data) {
      //self.robot.logger.info "post data: ", data
      // pretend like private messages are like mentions
      let message = data.raw;
      let pm = false;
      if ([6].indexOf(notification.notification_type) >= 0) {
        message = `${self.robot.name} ` + data.raw;
        pm = true;
      }
      self.emit(
        "message",
        data.id,
        data.topic_id,
        data.post_number,
        data.username,
        message,
        pm,
        self.server + notification.post_url,
        notification.topic_title
      );
    });
  }

  alertChannel(username, callback) {
    const self = this;
    if (this.userId) {
      callback(`/notification-alert/${this.userId}`);
    } else {
      this.getUser(username, function(user) {
        self.userId = user.id;
        self.alertChannel(username, callback);
      });
    }
  }

  getPost(notification, callback) {
    const self = this;
    request.get(
      `${this.server}/posts/by_number/${notification.topic_id}/${
        notification.post_number
      }.json?api_key=${this.key}`,
      { json: true },
      function(err, response, data) {
        if (err) {
          self.robot.logger.error("error when getting post: ", err);
        } else {
          callback(data);
        }
      }
    );
  }

  getUser(username, callback) {
    const self = this;
    request.get(
      `${this.server}/users/${username}.json?api_key=${this.key}`,
      { json: true },
      function(err, response, data) {
        if (err) {
          self.robot.logger.error("error when getting user: ", err);
        } else {
          const user = self.robot.brain.userForId(username, data.user);
          callback(user);
        }
      }
    );
  }

  reply({ message, topic_id, reply_to_post_number }) {
    const self = this;
    const target = `${this.server}/posts.json`;
    request.post(
      target,
      {
        form: {
          api_key: this.key,
          topic_id,
          reply_to_post_number,
          raw: message
        },
        json: true
      },
      function(err, response, body) {}
    );
  }

  post({ message, topic_id }) {
    const self = this;
    const target = `${this.server}/posts.json`;
    request.post(
      target,
      { form: { api_key: this.key, topic_id, raw: message }, json: true },
      function(err, response, body) {}
    );
  }

  pm({ message, title, usernames }) {
    const self = this;
    const target = `${this.server}/posts.json`;
    request.post(
      target,
      {
        form: {
          api_key: this.key,
          title,
          target_usernames: usernames,
          raw: message,
          archetype: "private_message"
        },
        json: true
      },
      function(err, response, body) {}
    );
  }
}
