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

## Limitations

Currently there is no reliable way to notify Hubot on messages other than `@username`, or by setting watched topics/categories to "watched" manually.
