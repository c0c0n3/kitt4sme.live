#
# Policy enforcement entry point.
# Delegate decisions to policies relevant for the request at hand.
#
# NOTE OPA hook. The OPA service is configured to evaluate the
# `allow` expression in this package---i.e. `data.kitt4sme.allow`,
# see `opa.yaml`. If you rename this package or the allow rule below,
# you'll have to change the pod config in `opa.yaml` accordingly.
#
package kitt4sme

import data.fiware.service as fiware
import data.mqtt.service as mqtt


default allow = false

allow {
    fiware.allow
}

# or

allow {
    mqtt.allow
}

# NOTE. These two policies are mutually exclusive. In fact, the
# first one will deny access if there's no FIWARE service header,
# but this header won't be in requests to "/mqtt/", which is the
# path the second policy protects.
