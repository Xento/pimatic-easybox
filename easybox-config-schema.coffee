module.exports = {
  title: "easybox config options"
  type: "object"
  properties: 
    password:
      description:"Password for web interface"
      type: "string"
      required: yes
    ip:
      description:"IP-Address of your router"
      type: "string"
      required: yes
    interval:
      description: "The time in ms, for querying the router"
      type: "number"
      default: 60
}
