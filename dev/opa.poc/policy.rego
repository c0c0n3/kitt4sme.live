package policy

import data.wac as wac


default allow = false

allow {
    wac.check(policy)
}

policy = {
    "joe.bloggs": {
        "/v2/entities/urn:foo": [wac.Read],
        "/v2/entities/urn:bar": [wac.Read, wac.Write]
    },
    "jane.doe": {
        "/v2/entities/urn:foo": [wac.Read, wac.Append]
    },
    "jane.austin": {
        "/v2/entities/urn:foo": [wac.Read]
    }
}
