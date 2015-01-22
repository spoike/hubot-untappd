# hubot-untappd

Simple hubot integration to [untappd](https://untappd.com/home)

## Installation

In hubot project repo, run:

```sh
npm install hubot-untappd --save
```

Then add `hubot-untappd` to your hubot's `external-scripts.json`:

```json
[
  "hubot-untappd"
]
```

## Configuration

You can obtain the client id and secret from untappd by logging in [here](https://untappd.com/api/register?register=new).

* `HUBOT_UNTAPPD_CLIENTID` - the untappd client id

* `HUBOT_UNTAPPD_SECRET` - the untappd secret string

* `HUBOT_UNTAPPD_ROOM` - the room to post updates to, default room is `#beer`

## Usage

The bot will poll untappd every 10 minutes for all registered users

* `hubot untappd help` - list all commands

* `hubot identify` - check which username the user has registered to hubot brain

* `hubot identify {untappd username}` - set untappd user name that will be used for user feed polling

* `hubot last {n} beers` - shows the last `n` beers you had, default `n` is 1