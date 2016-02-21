module.exports = {
  title: "enigma config options"
  type: "object"
  properties: 
    password:
      description:"Password for webinterface"
      default: ""
      required: yes
    ip:
      description:"IP-Address of your router"
      type: "string"
      default: ""
      required: yes
    interval:
      description: "The time in ms, for querying the router"
      type: "number"
      default: 60
}
