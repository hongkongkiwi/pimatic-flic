module.exports = {
  title: "Flic- Config Options"
  type: "object"
  properties:
    debug:
      description: "Debug mode. Writes debug messages to the pimatic log, if set to true."
      type: "boolean"
      default: false
    autoReconnect:
      description: "If the connection dies, should we automatically reconnect?"
      type: "boolean"
      default: true
    reconnectInterval:
      description: "If auto-reconnect is enabled, how many seconds to to wait before retrying to connect"
      type: "number"
      default: 60
    flicServiceHost:
      description: "Flic Service Daemon Host"
      type: "string"
      default: "localhost"
    flicServicePort:
      description: "Flic Service Daemon Port"
      type: "number"
      default: 5551
}
