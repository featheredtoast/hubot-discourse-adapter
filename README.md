# [Hubot Discourse adapter](https://www.npmjs.com/package/hubot-discourse-adapter)

A [Discourse](http://www.discourse.org/) adapter for [Hubot](https://hubot.github.com/).

A bot here will only be called in for topics it is notified for.

To get up and running, the adapter requires a few hubot variables to be set:
* `HUBOT_DISCOURSE_USERNAME` the username the bot will connect as.
* `HUBOT_DISCOURSE_KEY` the API key for the user. This needs to be a user API key, not a site-wide API key.
* `HUBOT_DISCOURSE_SERVER` the discourse server eg `https://discourse.example.com/`.

## Getting started

```
npm install -g yo generator-hubot
mkdir my-awesome-hubot && cd my-awesome-hubot
yo hubot --adapter=discourse-adapter
```

## Discourse configuration

By default, Discourse does not send users alert messages unless directly notified via `@username`, or by quoting.

In order to receive messages without a direct reply, you may either set the bot account's watched topics/categories to "watched" manually, or allow for "opt-in notifications".

For opt-in notifications, set the bot's user preferences, notifications and set `When I post in a topic, set that topic to` `Watching` After the first reply, Hubot will then listen for any post after its first reply.
