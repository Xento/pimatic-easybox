# #Easybox device configuration options
module.exports = {
  title: "pimatic-easybox device config schemas"
  EasyBoxDevicePresence: {
    title: "Easybox config options"
    type: "object"
    extensions: ["xLink", "xPresentLabel", "xAbsentLabel"]
    properties:
      hostname:
        description: "hostname of the device"
        type: "string"
      mac:
        description: "MAC of the device"
        type: "string"
        default: ""
        required: false
      ip:
        description: "IP of the device"
        type: "string"
        default: ""
        required: false
  }
  EasyBoxPhone: {
    title: "Easybox config options"
    type: "object"
    properties: {}
  }
}
