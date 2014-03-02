polar = require 'polar'
dbox = require 'dbox'
config = require './config'
util = require 'util'
_ = require 'underscore'

dropbox = dbox.app config.dropbox

base_url = 'http://localhost:' + config.app.port
oauth_callback = base_url + '/dropbox/connected'

app = polar.setup_app config.app

# Show the page with a 
app.get '/', (req, res) ->
    console.log util.inspect req.session
    if req.session.access_token
        dropbox_client = dropbox.client req.session.access_token

        dropbox_client.account (status, account_data) ->
            res.end "You seem to be #{ account_data.display_name }."

    else
        res.render 'connect'

# Keep track of request tokens between authentication steps
# and the access tokens for successful authentications
pending_request_tokens = {}
access_tokens = {}

# Begin the authorization with Dropbox
app.get '/dropbox/connect', (req, res) ->

    # Create and save the pending request token
    dropbox.requesttoken (status, request_token) ->
        pending_request_tokens[request_token.oauth_token] = request_token

        # Direct the user to Dropbox's authorization URL
        res.redirect request_token.authorize_url + '&oauth_callback=' + oauth_callback

# Dropbox is told to redirect here upon succesful authorization
app.get '/dropbox/connected', (req, res) ->

    # Find the request token in our pending dictionary
    request_token = pending_request_tokens[req.query.oauth_token]

    if request_token

        # Create and save the authorized access token
        dropbox.accesstoken request_token, (status, access_token) ->
            access_tokens[access_token.oauth_token] = access_token
            req.session.access_token = access_token
            req.session.save ->

                dropbox_client = dropbox.client access_token

                dropbox_client.account (status, account_data) ->
                    res.end "You seem to be #{ account_data.display_name }."

    # Pending token not recognized
    else
        res.end 'Failed to connect.'

app.start()
