polar = require 'polar'
dbox = require 'dbox'
config = require './config'
util = require 'util'
_ = require 'underscore'

dropbox = dbox.app config.dropbox

base_url = 'http://localhost:' + config.app.port
oauth_callback = base_url + '/dropbox/connected'

app = polar.setup_app config.app

# Dropbox authentication middleware
# Ensures a user is authenticated by inspecting the access token
# in their session data, redirecting to the connect page otherwise
auth_dropbox = (req, res, next) ->
    if req.session.access_token
        dropbox_client = dropbox.client req.session.access_token
        res.locals.dropbox = dropbox_client
        next()
    else
        res.render 'connect'

# Show the page with a 
app.get '/', auth_dropbox, (req, res) ->
    res.locals.dropbox.account (status, account_data) ->
        res.render 'welcome', account_data

# List files
app.get /\/dropbox\/files\/(.*)/, auth_dropbox, (req, res) ->

    root_dir = '/' + req.params[0]
    res.locals.dropbox.metadata root_dir, {root: 'dropbox'}, (status, dir_metadata) ->

        res.render 'files',
            dir: root_dir
            files: dir_metadata.contents

# Read a file
app.get /\/dropbox\/file\/(.*)/, auth_dropbox, (req, res) ->

    filename = '/' + req.params[0]
    res.locals.dropbox.get filename, {root: 'dropbox'}, (status, file, metadata) ->

        res.end file.toString()

# Keep track of request tokens between authentication steps
pending_request_tokens = {}

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
            req.session.access_token = access_token
            req.session.save ->

                dropbox_client = dropbox.client access_token

                dropbox_client.account (status, account_data) ->
                    res.end "You seem to be #{ account_data.display_name }."

    # Pending token not recognized
    else
        res.end 'Failed to connect.'

app.start()
