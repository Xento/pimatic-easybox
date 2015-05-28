# #easybox Plugin
# ##The plugin code

# Your plugin must export a single function, that takes one argument and returns a instance of
# your plugin class. The parameter is an envirement object containing all pimatic related functions
# and classes. See the [startup.coffee](http://sweetpi.de/pimatic/docs/startup.html) for details.
module.exports = (env) ->

  {EventEmitter} = env.require 'events'
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  util = env.require 'util'
 
  request = require 'request'
  #require('request').debug = true
  tough = require 'tough-cookie'
  M = env.matcher
  emitter = new EventEmitter
  ip = ""
  password = ""
  interval = 60000
  
  class easyboxPlugin extends env.plugins.Plugin
    # ####init()
    init: (app, @framework, config) =>
      ip = config.ip
      password = config.password
      
      @deviceCount = 0
      deviceConfigDef = require("./device-config-schema")
      
      @framework.deviceManager.registerDeviceClass("EasyBoxDevicePresence", {
        configDef: deviceConfigDef.EasyBoxDevicePresence, 
        createCallback: (config, lastState) => 
          device = new EasyBoxDevicePresence(config, lastState, @deviceCount)
          @deviceCount++
          return device
      })
      
      if config.interval <= 0
        config.interval = 60
      
      interval = config.interval * 1000
      
      request = request.defaults({jar: true})
      
      updateTimer = =>        
        request.post {
          url: 'http://'+ip+'/cgi-bin/login.exe'
          form: pws: password
        }, (err, httpResponse, body) ->
          request.get {
            url: 'http://'+ip+'/overview_info.js'
          }, (err, httpResponse, body) ->
          
            re = /var wifi_\d = \['([^']*)', '([^']*)', '([^']*)'/g
            m = undefined
            devices = []
            
            while m = re.exec(body)
              t = [m[1], m[2], m[3]]
              devices.push t
              
            emitter.emit "update", devices
          return
        
        setTimeout(updateTimer, config.interval) 

      updateTimer()
          
  # Create a instance of my plugin
  plugin = new easyboxPlugin()

  class EasyBoxDevicePresence extends env.devices.PresenceSensor
    constructor: (@config, lastState, deviceNum) ->
      @name = @config.name
      @id = @config.id
      @_presence = lastState?.presence?.value or false
      
      emitter.on('update', (devices) => 
        env.logger.debug "Device"
        
        for device in devices
          if @config.hostname == device[2]
            @_setPresence yes
            env.logger.debug "Discovered device " + @config.name + " over hostname"
            return
          
          if @config.mac == device[0]
            @_setPresence yes
            env.logger.debug "Discovered device " + @config.name + " over MAC"
            return
          
          if @config.ip == device[1] 
            @_setPresence yes
            env.logger.debug "Discovered device " + @config.name + " over ip"
            return

        @_setPresence no
      )
      
      super()

    getPresence: ->
      if @_presence? then return Promise.resolve @_presence
      return new Promise( (resolve, reject) =>
        @once('presence', ( (state) -> resolve state ) )
      ).timeout(interval + 5*60*1000)

  
  # and return it to the framework.
  return plugin   
