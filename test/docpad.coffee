# DocPad Configuration File
# http://docpad.org/docs/config

# Import
request = require('request')

# Use values from .env file
site = process.env.CONFLUX_SITE
user = process.env.CONFLUX_USER
pass = process.env.CONFLUX_PW
# Key for test space
spaceKey = 'TESTCONFLUX'

# Define the DocPad Configuration
docpadConfig = {
  # Plugin configuration
  plugins:
    cachr:
      feedrOptions:
        requestOptions:
          auth:
            user: user
            pass: pass
    conflux:
      collections: [
        spaceKey: spaceKey
      ]
  events:
    # Use docpadReady event to prepare space
    docpadReady: (opts) ->
      docpad = @docpad
       # Create private test space CONFLUX
      reqCreateSpace =
        url: "#{site}/rest/api/space/_private"
        method: "POST"
        body:
          key: spaceKey
          name: "Test Conflux Space"
        auth:
          user: user
          pass: pass
        json: true
      request reqCreateSpace, (err, res, data) ->
        if res.statusCode is 400
          docpad.log('info', "#{data.message}")
      # Add content to test space
      reqCreatePageOne =
        url: "#{site}/rest/api/content"
        method: "POST"
        body:
          type: "page"
          title: "Test One"
          space:
            key: spaceKey
          body:
            storage:
              value: "<p>This is one test page.</p>"
              representation: "storage"
        auth:
          user: user
          pass: pass
        json: true
      request reqCreatePageOne, (err, res, data) ->
        if res.statusCode is 400
          docpad.log('info', "#{data.message}")
      reqCreatePageTwo =
        url: "#{site}/rest/api/content"
        method: "POST"
        body:
          type: "page"
          title: "Test Two"
          space:
            key: spaceKey
          body:
            storage:
              value: "<p>This is another test page.</p>"
              representation: "storage"
        auth:
          user: user
          pass: pass
        json: true
      request reqCreatePageTwo, (err, res, data) ->
        if res.statusCode is 400
          docpad.log('info', "#{data.message}")
    # Use docpadDestroy event to delete test space
#    docpadDestroy: (opts) ->
#      docpad = @docpad
#      # Delete private test space
#      reqDeleteSpace =
#        url: "#{site}/rest/api/space/#{spaceKey}"
#        method: "DELETE"
#        auth:
#          user: user
#          pass: pass
#      request reqDeleteSpace, (err, res, data) ->
#        if res.statusCode is 400
#          docpad.log('info', "#{data.message}")
}

# Export the DocPad Configuration
module.exports = docpadConfig
