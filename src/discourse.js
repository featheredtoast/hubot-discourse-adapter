const { Adapter, TextMessage } = require("hubot/es2015");

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
      this.connector.pm(pm_envelope);
    } else if (envelope.pm && !envelope.message.pm) {
      pm_envelope = {
        message: envelope.message.slug + os.EOL + message,
        title: `About your post in ${envelope.message.title}`,
        usernames: envelope.user.username
      };
      this.robot.logger.info("PM", pm_envelope);
      this.connector.pm(pm_envelope);
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
      this.connector.reply(reply_envelope);
    } else if (typeof envelope.room === "number") {
      const send_envelope = {
        topic_id: envelope.room,
        message
      };
      this.robot.logger.info("Send", send_envelope);
      this.connector.post(send_envelope);
    }
  }

  reply(envelope, ...strings) {
    strings[0] = `@${envelope.user.username} ${strings[0]}`;
    this.send(envelope, ...strings);
  }

  run() {
    this.robot.logger.info("Run");
    const options = {
      username: process.env.HUBOT_DISCOURSE_USERNAME,
      key: process.env.HUBOT_DISCOURSE_KEY,
      server: process.env.HUBOT_DISCOURSE_SERVER
    };
    this.robot.name = options.username;
    this.connector = new DiscoursePoller(options, this.robot);
    this.connector.listen();
    this.connector.on(
      "message",
      (post_id, topic_id, post_number, username, raw, pm, slug, title) =>
        this.connector.getUser(username, user => {
          user.room = topic_id;
          const message = new TextMessage(user, raw, post_number);
          message.pm = pm;
          message.title = title;
          message.slug = slug;
          this.robot.receive(message);
        })
    );
    this.emit("connected");
  }
}

exports.use = robot => new Discourse(robot);

class DiscoursePoller extends EventEmitter {
  constructor(options, robot) {
    super(...arguments);
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
    this.alertChannel(this.username, channel => {
      messageBus.bus.apiKey = this.key;
      messageBus.bus.baseUrl = this.server + "/";
      messageBus.bus.subscribe(channel, notification =>
        this.handleNotification(notification)
      );
    });
  }

  handleNotification(notification) {
    this.robot.logger.info("got notification: ", notification);
    this.getPost(notification, data => {
      //this.robot.logger.info "post data: ", data
      // pretend like private messages are like mentions
      let message = data.raw;
      let pm = false;
      if ([6].indexOf(notification.notification_type) >= 0) {
        message = `${this.robot.name} ` + data.raw;
        pm = true;
      }
      this.emit(
        "message",
        data.id,
        data.topic_id,
        data.post_number,
        data.username,
        message,
        pm,
        this.server + notification.post_url,
        notification.topic_title
      );
    });
  }

  alertChannel(username, callback) {
    if (this.userId) {
      callback(`/notification-alert/${this.userId}`);
    } else {
      this.getUser(username, user => {
        this.userId = user.id;
        this.alertChannel(username, callback);
      });
    }
  }

  getPost(notification, callback) {
    request.get(
      `${this.server}/posts/by_number/${notification.topic_id}/${
        notification.post_number
      }.json?api_key=${this.key}`,
      { json: true },
      (err, response, data) => {
        if (err) {
          this.robot.logger.error("error when getting post: ", err);
        } else {
          callback(data);
        }
      }
    );
  }

  getUser(username, callback) {
    request.get(
      `${this.server}/users/${username}.json?api_key=${this.key}`,
      { json: true },
      (err, response, data) => {
        if (err) {
          this.robot.logger.error("error when getting user: ", err);
        } else {
          const user = this.robot.brain.userForId(username, data.user);
          callback(user);
        }
      }
    );
  }

  reply({ message, topic_id, reply_to_post_number }) {
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
      (err, response, body) => {}
    );
  }

  post({ message, topic_id }) {
    const target = `${this.server}/posts.json`;
    request.post(
      target,
      { form: { api_key: this.key, topic_id, raw: message }, json: true },
      (err, response, body) => {}
    );
  }

  pm({ message, title, usernames }) {
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
      (err, response, body) => {}
    );
  }
}
