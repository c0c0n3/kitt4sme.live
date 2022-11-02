#
# Placeholder policy for MQTT.
#
# We expose MQTT over WebSocket at "/mqtt/". This policy allows any
# incoming traffic to that path. The reason is that, at the moment,
# the MQTT WebSocket listener is configured with its own password
# file. So it kinda takes security in its own hands.
#
# Going forward we could use OPA policies instead to protect the MQTT
# WebSocket endpoint. For it to work smoothly, we could require clients
# to specify additional security headers in the WebSocket handshake
# request---e.g. topic, JWT, etc. Then MQTT OPA policies would use
# those headers to allow or deny access.
#

package mqtt.service

import input.attributes.request.http as http_request


default allow = false

allow = true {
    regex.match("^/mqtt/.*", http_request.path)
}
