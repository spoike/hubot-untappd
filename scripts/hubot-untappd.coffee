# Description:
#   Access untappd with hubot
#
# Commands:
#   hubot untappd - get a list of commands for untappd
#
# Author:
#   spoike

untappd = new (require('node-untappd'))(false)
_ = require 'lodash'
cronjob = require("cron").CronJob
moment = require "moment"

UPDATE_TIME = "00 */10 * * * *" # erry minute of erry day, son
ROOM = process.env.HUBOT_UNTAPPD_ROOM || "beer"

untappd.setClientId process.env.HUBOT_UNTAPPD_CLIENTID
untappd.setClientSecret process.env.HUBOT_UNTAPPD_SECRET

UNTAPPD_BRAIN_KEY = 'hubot_untappd_users'

handleUserFeed = (user, cb) ->
  (err,o) ->
    return console.error(err) if err
    if o.response.checkins.count > 0
      checkins = o.response.checkins.items
      cb(checkins) if cb
      user.untappd.last_checkins = checkins
      user.untappd.max_id = _(checkins).map("checkin_id").max().valueOf()

getUserFeed = (user, cb) ->
  user_name = user.untappd.user_name
  max_id = user.untappd.max_id
  if max_id
    untappd.userFeed handleUserFeed(user, cb), user_name, 10
  else
    untappd.userFeed handleUserFeed(user, cb), user_name, 1

availableActionNames = (rating) ->
  if rating && rating <= 2.0
    # bad
    ["choked down a", "managed to finish a", "reluctantly tried a", "kept down a", "shouldn't have had a"]
  else if !rating || rating <= 4.0
    # normal
    ["drank a", "had a", "purchased a", "slammed a", "chugged a", "downed a", "imbibed a", "hammed a", "slurped a"]
  else
    # good
    ["thoroughly enjoyed a", "quenched their thurst with a", "drowned themselves in"]

actionNameFor = (rating) ->
  possible = availableActionNames(rating)
  possible[Math.floor(Math.random() * possible.length)]

formatCheckin = (checkin, withName) ->
  beer_name = checkin.beer.beer_name
  user_name = "#{checkin.user.first_name} #{checkin.user.last_name.charAt(0)}"
  brewery_name = checkin.brewery.brewery_name
  rating_score = checkin.rating_score
  rating_phrase = if rating_score > 0 then "and rated it *#{rating_score}/5*" else ""
  action = actionNameFor(rating_score)
  venue = if checkin.venue.venue_name then "at #{checkin.venue.venue_name}" else ""

  return ":beer: *#{user_name}* #{action} *#{beer_name}* from _#{brewery_name}_ #{rating_phrase} #{venue}" if withName
  ":beer: *#{beer_name}* from _#{brewery_name}_ #{rating_phrase} #{venue}"

module.exports = (robot) ->

  getUntappdUserIds = () ->
    userIds = robot.brain.get UNTAPPD_BRAIN_KEY
    if !userIds
      userIds = []
      robot.brain.set UNTAPPD_BRAIN_KEY, userIds
    userIds

  update = () ->
    untappdUserIds = getUntappdUserIds()
    if untappdUserIds and untappdUserIds.length > 0
      _.each untappdUserIds, (userId) ->
        user = robot.brain.userForId userId
        return if !user.untappd
        getUserFeed user, (checkins) ->
          _(checkins).filter (checkin) ->
              checkin.checkin_id > user.untappd.max_id
            .each (checkin) ->
              m = formatCheckin(checkin, true)
              robot.messageRoom ROOM, m

  updater = new cronjob UPDATE_TIME,
    -> update()
    null
    true

  robot.respond /untappd( help)?$/i, (msg) ->
    helpText = "Following commands exist:\n" +
      "`hubot untappd identify` - what username I identify you with\n" +
      "`hubot untappd identify {username}` - set your username\n" +
      "`hubot untappd [last] [n] beer(s)` - shows the last `n` beers you had, default `n` is 1, max `n` is 10"
    msg.reply helpText

  robot.respond /untappd identify$/i, (msg) ->
    id = msg.envelope.user.id
    user = robot.brain.userForId(id)
    return msg.reply("You haven't set your username") if !user.untappd
    msg.reply "Your untappd username is #{user.untappd.user_name}"

  robot.respond /untappd identify (.*)$/i, (msg) ->
    id = msg.envelope.user.id
    user = robot.brain.userForId(id)
    userName = msg.match[1]
    user.untappd =
      user_name: userName
    msg.reply "I have set your username to #{userName}"
    getUserFeed user, (checkins) ->
      return msg.reply("You haven't made any check-in on any beer at untappd yet") if checkins.length < 1
      lastCheckin = _.first checkins
      m = formatCheckin(lastCheckin, false)
      msg.reply("Your last :beer: was #{m}")
    userIds = getUntappdUserIds()
    userIds.push(id)

  robot.respond /untappd(( last)?( \d+)|( last))? :?beers?:?$/i, (msg) ->
    num = msg.match[1].match(/\d+/) if _.isString msg.match[1]
    num = parseInt(num[0], 10) if num and num[0]
    num = 1 if !(_.isNumber(num)) or num < 1
    num = 10 if num > 10
    user = robot.brain.userForId(msg.envelope.user.id)
    return msg.reply("You haven't set your username") if !user.untappd
    checkins = user.untappd.last_checkins
    return msg.reply("You haven't made any check-in on any beer at untappd yet") if !checkins or checkins.length < 1
    m = ""
    if num is 1
      lastCheckin = _.first checkins # checkins apparently come in reverse order
      m = formatCheckin(lastCheckin, false)
    else
      m = _(checkins).map (ci) ->
            formatCheckin(ci, false)
        .take(num)
        .join("\n")
    msg.reply(m)
