# Hubot Discourse adapter

A discourse adapter for hubot.

A bot here will only be called in for topics it is notified for.

To get up and running, the adapter requires a few hubot variables to be set:
`HUBOT_DISCOURSE_USERNAME` the username the bot will connect as.
`HUBOT_DISCOURSE_KEY` the API key for the user. This needs to be a user API key, not a site-wide API key.
`HUBOT_DISCOURSE_SERVER` the discourse server eg `https://discourse.example.com/`.



## Limitations

Currently there is no reliable way to notify Hubot on messages other than `@username`, or by setting watched topics/categories to "watched" manually.

The notifications roll up so only the first notification per batch will be responded to. The poll is on a 10 second timer. There is no pagination in the polling so only the most recent 60 messages notifications will be responded to.

The discourse adapter requires a user that can use the API -- the bot may need to be promoted to staff.
