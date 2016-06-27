module.exports = {
  title: "FlicButtonPlugin device config schemas"
  FlicButtonDevice: {
    title: "FlicButtonDevice config options"
    extensions: ["xLink"]
    type: "object"
    #required: ["start_latitude","start_longitude","end_latitude","end_longitude"]
    properties:
      buttons:
        description: "Buttons to display"
        type: "array"
        default: []
        format: "table"
        items:
          type: "object"
          properties:
            id:
              description: "Button id"
              type: "string"
            text:
              description: "Button text"
              type: "string"
            hardwareAddress:
              description: "FlicButton HW Mac Address"
              type: "string"
            confirm:
              description: "Ask the user to confirm the button press"
              type: "boolean"
              default: false
    }
}
