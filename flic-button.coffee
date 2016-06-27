module.exports = (env) ->
  # ##Dependencies
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  _ = env.require 'lodash'
  events = env.require 'events'

  fliclib = require './lib/fliclibNodeJs'
  FlicClient = fliclib.FlicClient
  FlicConnectionChannel = fliclib.FlicConnectionChannel
  FlicScanner = fliclib.FlicScanner

 # deviceConfigTemplates = {
 #    "relay": {
 #      id: "unipi-relay-"
 #      name: "UniPi Relay "
 #      class: "UniPiRelay"
 #    }
 #    "ai": {
 #      "id": "unipi-analog-input-"
 #      "class": "UniPiAnalogInput"
 #      "name": "UniPi Analog Input "
 #    }
 #    "ao": {
 #      "id": "unipi-analog-output-"
 #      "class": "UniPiAnalogOutput"
 #      "name": "UniPi Analog Output "
 #    }
 #    "input": {
 #      "id": "unipi-digital-input-"
 #      "class": "UniPiDigitalInput"
 #      "name": "UniPi Digital Input "
 #    }
 #    "temp": {
 #      "id": "unipi-temperature-"
 #      "class": "UniPiTemperature"
 #      "name": "UniPi Temperature "
 #    }
 #  }

  # ##The PingPlugin
  class FlicButtonPlugin extends env.plugins.Plugin

    _listenToButton: (bdAddr) =>
    	cc = new FlicConnectionChannel bdAddr
    	@flicClient.addConnectionChannel cc

    	cc.on "buttonUpOrDown", (clickType, wasQueued, timeDiff) =>
    		console.log "#{bdAddr} #{clickType} #{if wasQueued? then "wasQueued" else "notQueued"} #{timeDiff} seconds ago"

    	cc.on "connectionStatusChanged", (connectionStatus, disconnectReason) =>
        console.log "#{bdAddr} #{connectionStatus} #{if connectionStatus is "Disconnected" then " #{disconnectReason}" else ""}"

    _connectToFlicDaemon: () =>
      @flicClient = new FlicClient @config.flicServiceHost, @config.flicServicePort
      @shownError = false

      if @flicClient?
        @flicClient.once "ready", () =>
          clearInterval @retryTimerId if @retryTimerId?
          @flicClient.getInfo (info) =>
            if @config.debug and info?
              env.logger.debug "Connected to Daemon!"

        @flicClient.on "bluetoothControllerStateChange", (state) =>
        	env.logger.debug "Bluetooth controller state change: #{state}"

        @flicClient.on "newVerifiedButton", (bdAddr) =>
        	env.logger.info "A new button was added: #{bdAddr}"
        	@._listenToButton bdAddr

        @flicClient.on "error", (error) =>
          if @config.debug
            if error? and error.code is 'ECONNREFUSED'
              env.logger.error "Could not connect to FlicLib Server #{@config.flicServiceHost}:#{@config.flicServicePort}"
            else
          	   env.logger.error "Daemon connection error: #{error}"

        @flicClient.on "close", (hadError) =>
            if @config.debug
              if hadError? and hadError is false
            	  env.logger.warn "Lost Connection to Daemon."
              else
            	  env.logger.warn "Unable to establish a connection to Daemon."
              if @config.reconnectInterval > 0 and @config.autoReconnect
                @retryTimerId = setTimeout( ( =>
                  env.logger.warn "Attempting to reconnect to Daemon..."
                  @_connectToFlicDaemon()
                ), @config.reconnectInterval * 1000)
              else
                env.logger.error "Auto-Reconnect is enabled, but the interval is set to 0. Should be 1 or greater!"

    init: (app, @framework, @config) =>
      # ping package needs root access...
      # if os.platform() isnt 'win32' and process.getuid() != 0
      #   throw new Error "ping-plugins needs root privileges. Please restart the framework as root!"
      @deviceCount = 0

      @_connectToFlicDaemon()

      deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass "FlicButtonDevice", {
        configDef: deviceConfigDef.FlicButtonDevice,
        createCallback: (config, lastState) =>
          device = new FlicButtonDevice config, @
          @deviceCount++
          return device
      }

      # for key, device of deviceConfigTemplates
      #   do (key, device) =>
      #     className = device.class
      #     # convert camel-case classname to kebap-case filename
      #     filename = className.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase()
      #     classType = require('./devices/' + filename)(env)
      #     @_base.debug "Registering device class #{className}"
      #     @framework.deviceManager.registerDeviceClass(className, {
      #       configDef: deviceConfigDef[className],
      #       createCallback: (config, lastState) =>
      #         return new classType(config, @, lastState)
      #     })

      # Discover Flic buttons
      @framework.deviceManager.on('discover', (eventData) =>
        console.log('discover!');
        @framework.deviceManager.discoverMessage(
          'pimatic-flic-button', "Searching for Buttons"
        )
        @flicClient.getInfo (info) =>
          if @config.debug and info?
            env.logger.debug "Connected to Daemon!"

          buttons = []
          done = _.after info.bdAddrOfVerifiedButtons.length, () =>
            console.log('found verified buttons!',buttons)
            config = {
              "name": "Flic Buttons",
              "id": "flic-button-demo",
              "class": "FlicButtonDevice",
              "buttons": buttons
            }
            @framework.deviceManager.discoveredDevice(
              'pimatic-flic-button', "Found #{buttons.length} verified buttons", config
            )

          _.forEach(info.bdAddrOfVerifiedButtons, (bdAddr, i) =>
            if @config.debug? is true
              env.logger.debug "Found verified button #{bdAddr}"
            buttons.push {
              "id": "button-#{i}",
              "text": "Press me",
              "hardwareAddress": bdAddr,
              "confirm": false
            }
            done()
          )
      )
      # 	@flicClient.getInfo (info) =>
      #     if @config.debug and info?
      #       env.logger.debug "Connected to Daemon!"
      #     if info?.bdAddrOfVerifiedButtons? then
    	# 	    info.bdAddrOfVerifiedButtons.forEach (bdAddr) =>
      #         if @config.debug? is true
      #           env.logger.debug "Found verified button #{bdAddr}"
      #           config = {
      #             class: 'FlicButtonDevice',
      #             name: bdAddr,
      #             hardwareAddress: bdAddr
      #           }
      #           @framework.deviceManager.discoveredDevice(
      #             'pimatic-ping', "Found verified button #{bdAddr}", config
      #           )
        			  #@._listenToButton bdAddr
        # displayName = (
        #   if hostnames? and hostnames.length > 0 then hostnames[0] else address
        # )
        # config = {
        #   class: 'PingPresence',
        #   name: displayName,
        #   hardwareAddress: displayName
        # }
        # @framework.deviceManager.discoveredDevice(
        #   'pimatic-ping', "Presence of #{displayName}", config
        # )
          # if pingCount > maxPings
          #   @framework.deviceManager.discoverMessage(
          #     'pimatic-ping', "Could not ping all networks, max ping cound reached."
          #   )

    # destroy: () ->
    #   clearInterval @intervalTimerId if @intervalTimerId?
    #   super()

  flicButtonPlugin = new FlicButtonPlugin

  class FlicButtonDevice extends env.devices.ButtonsDevice
    actions:
      buttonPressed:
        params:
          buttonId:
            type: "string"
        description: "Press a button"
      buttonHeld:
        params:
          buttonId:
            type: "string"
        description: "Hold a button"

    constructor: (@config, @plugin)->
      @id = @config.id
      @name = @config.name
      @flicClient = @plugin.flicClient

      for b in @config.buttons
        cc = new FlicConnectionChannel b.hardwareAddress

        cc.on "buttonUpOrDown", (clickType, wasQueued, timeDiff) =>
          @buttonPressed b.id
          env.logger.debug "#{b.hardwareAddress} #{clickType} #{if wasQueued? then "wasQueued" else "notQueued"} #{timeDiff} seconds ago"

        cc.on "connectionStatusChanged", (connectionStatus, disconnectReason) =>
          env.logger.debug "connectionStatusChanged #{b.hardwareAddress} #{connectionStatus} #{if connectionStatus is "Disconnected" then " #{disconnectReason}" else ""}"

        @flicClient.addConnectionChannel cc

      super(@config)

    getButton: -> Promise.resolve(@_lastPressedButton)

    buttonPressed: (buttonId) ->
      for b in @config.buttons
        if b.id is buttonId
          @_lastPressedButton = b.id
          @emit 'button', b.id
          return
      throw new Error("No button with the id #{buttonId} found")

    destroy: () ->
      # for b in @config.buttons
      #   if b.stateTopic
      #     @plugin.mqttclient.unsubscribe(b.stateTopic)
      super()


  # ##FlicButtonDevice
  # class FlicButtonDevice extends env.devices.ButtonsDevice
  #
  #   constructor: (@config, @plugin) ->
  #     @name = @config.name
  #     @id = @config.id
  #     @hwAddr = @config.hardwareAddress
  #     @flicClient = @plugin.flicClient
  #
  #     console.log @hwAddr
  #
  #     cc = new FlicConnectionChannel @hwAddr
  #
  #     cc.on "buttonUpOrDown", (clickType, wasQueued, timeDiff) =>
  #       console.log "#{bdAddr} #{clickType} #{if wasQueued? then "wasQueued" else "notQueued"} #{timeDiff} seconds ago"
  #
  #     cc.on "connectionStatusChanged", (connectionStatus, disconnectReason) =>
  #       console.log "#{bdAddr} #{connectionStatus} #{if connectionStatus is "Disconnected" then " #{disconnectReason}" else ""}"
  #
  #     @flicClient.addConnectionChannel cc
  #
  #     super @config
      # if @plugin.connected
      #   @onConnect()
      #
      # @plugin.mqttclient.on('connect', =>
      #   @onConnect()
      # )
      #
      # for b in @config.buttons
      #   if b.stateTopic
      #     @plugin.mqttclient.on 'message', (topic, message) =>
      #       if b.stateTopic == topic
      #         payload = message.toString()
      #       if payload == b.message
      #         @emit 'button', b.id

    # buttonPressed: (buttonId) ->
    #   for b in @config.buttons
    #     if b.id is buttonId
    #       @emit 'button', b.id
    #       @plugin.mqttclient.publish(b.topic, b.message, { qos: b.qos or 0 })
    #       return
    #
    # onConnect: () ->
    #   for b in @config.buttons
    #     if b.stateTopic
    #       @plugin.mqttclient.subscribe(b.stateTopic, { qos: b.qos or 0 })

  # For testing...
  flicButtonPlugin.FlicButtonDevice = FlicButtonDevice

  return flicButtonPlugin
