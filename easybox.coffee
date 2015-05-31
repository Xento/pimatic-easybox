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
  interval = 120000
  
  class easyboxPlugin extends env.plugins.Plugin
    # ####init()
    init: (app, @framework, config) =>
      ip = config.ip
      password = config.password
      
      @framework.ruleManager.addPredicateProvider new EasyboxPredicateProvider(@framework)
      
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
        config.interval = 120
      
      interval = config.interval * 1000
      
      request = request.defaults({jar: true})
      
      LoggedIn = false
      LoggingIn = false
      LastLogin = 0
      CallCount = -1
      
      Refresh = =>
        env.logger.debug "Refreshing"
        # get online status
        request.get {
          url: 'http://'+ip+'/overview_info.js'
        }, (err, httpResponse, body) ->
          
          # check if still logged in
          re = /<title>Vodafone Vox UI/
          if re.exec(body)
            # check if we already tried to relogin
            if LoggingIn
              @Running = false
              LoggingIn = false
              return
            
            # try to login again
            LoggedIn = false
            LoggingIn = true
            LogIn()
            Refresh()
            return 
          else
            LoggedIn = true
          
          # get device status
          re = /var wifi_\d = \['([^']*)', '([^']*)', '([^']*)'/g
          devices = []
          m = undefined
          while m = re.exec(body)
            t = [m[1], m[2], m[3]]
            env.logger.debug "Device online: "+m[2]+" "+m[1]+" "+m[3]
            devices.push t
          
          emitter.emit "update", devices
          
          # get phone status
          request.get {
            url: 'http://'+ip+'/inc/phone/call-log.stm'
          }, (err, httpResponse, body) ->
            re = /CallState\[\d\] = 0\;\nPhone\[\d*\] ='(\d*)'\;\nphonebook_name\[\d*\] ='(.*)';\nphonebook_phone_name\[\d\] ='(.*)';\n.*\n.*\n.*\nsttime\[\d\] ='(.*)';/g
            missedcalls = []
            m = undefined
            calls = 0;
            
            while m = re.exec(body)
              call = {
                time: m[4]
                number: m[1]
                contact: m[2]
                numbername: m[3]
              }
              
              env.logger.debug call
              missedcalls.push call
              calls++
              
            if CallCount != calls 
              i = 0
              while i < calls - CallCount
                emitter.emit 'MissedCall'
                i++
            
            CallCount = calls
            #emitter.emit "update", devices
            return

      LogIn = =>
        env.logger.debug "Logging in"
        # Login
        request.post {
          url: 'http://'+ip+'/cgi-bin/login.exe'
          form: pws: password
        }, (err, httpResponse, body) ->
          LoggedIn = true
          Refresh()
          
          # Clear old Logins
          if new Date().getTime() - LastLogin > 3600 * 1000
            LogOut()
            
            LastLogin = new Date().getTime()
      
      LogOut = =>
        env.logger.debug "Logging out"
        
        request.get {
          url: 'http://'+ip+'/main_overview.stm'
        }, (err, httpResponse, body) ->
          re = /_httoken = (\d*)/g
          m1 = undefined
          
          if m1 = re.exec(body)
            request.post {
              url: 'http://'+ip+'/cgi-bin/logout.exe'
              form: httoken: m1[1]
            }
            LoggedIn = false
      
      updateTimer = =>
        LoggingIn = false

        if LoggedIn
          Refresh()
        else
          LogIn()
          
        setTimeout(updateTimer, interval) 

      updateTimer()
      
  # Create a instance of my plugin
  plugin = new easyboxPlugin()

  class EasyBoxDevicePresence extends env.devices.PresenceSensor
    constructor: (@config, lastState, deviceNum) ->
      @name = @config.name
      @id = @config.id
      @_presence = lastState?.presence?.value or false
      
      emitter.on('update', (devices) => 
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
        env.logger.debug "Device " + @config.name + " is offline"
        @_setPresence no
      )
      
      super()

    getPresence: ->
      if @_presence? then return Promise.resolve @_presence
      return new Promise( (resolve, reject) =>
        @once('presence', ( (state) -> resolve state ) )
      ).timeout(interval + 5*60*1000)

  class EasyboxPredicateProvider extends env.predicates.PredicateProvider
    listener: []

    constructor: (@framework) ->

    parsePredicate: (input, context) ->
      m = M(input, context).match("call missed")
      
      if m.hadMatch()
        token = m.getFullMatch()
        return {
          token: token
          nextInput: input.substring(token.length)
          predicateHandler: new EasyboxPredicateHandler(this)
        }
      return null

  class EasyboxPredicateHandler extends env.predicates.PredicateHandler

    constructor: (@provider) ->

    setup: ->
      emitter.on('MissedCall', => 
        @emit('change', 'event')
      )
      super()
    getValue: -> Promise.resolve(false)
    destroy: -> 
      super()
    getType: -> 'event'
  
  # and return it to the framework.
  return plugin   
