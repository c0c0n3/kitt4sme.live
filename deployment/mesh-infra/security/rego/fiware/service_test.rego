#
# Basic tests for `service.rego`.
# TODO add test cases for corner cases, e.g. missing fields.
#
# To run the tests:
#
# $ cd poc/deployment/opa/rego
# $ opa test . -v
#

package fiware.service


test_deny_expired_token {
    not allow with input as {
        "attributes": {
            "request": {
                "http": {
                    "headers": {
                        "fiware-service": tenant,
                        "authorization": expired_token
                    }
                }
            }
        }
    }
}

test_deny_tenant_mismatch {
    not allow with input as {
        "attributes": {
            "request": {
                "http": {
                    "headers": {
                        "fiware-service": "dodgy-tenant",
                        "authorization": valid_token
                    }
                }
            }
        }
    }
}

test_allow_valid_request {
    allow with input as {
        "attributes": {
            "request": {
                "http": {
                    "headers": {
                        "fiware-service": tenant,
                        "authorization": valid_token
                    }
                }
            }
        }
    }
}

tenant := "csic"
valid_token := "Bearer eyJhbGciOiAiUlMyNTYiLCAidHlwIjogIkpXVCJ9.eyJleHAiOiAxMDAwMDAwMDAwMCwgInRlbmFudCI6ICJjc2ljIn0.LI_JyTcw6yDwki3aOkD_5Q4G3-i_2OayE1R4u1E8UVaNOrDWkaMIqG-SNd3662F3lymZaTyIdNxIA_eLumjU2YrIWT4u5UMFQ52IxjKD_ujXhGISrzoRJEmztmVgHieD0NOHRKXuhVL8EmQcB5_dhsj4YVeP2tFaClEi5TmZKrVXa4UpPSbb9ZkuGyl-CADLY3e4TCIN5iMJz5paHJ4Zbd3mJTn83fIY9UBcMz3vTH7pqsjdxjIBjiKMOievDt89ZfmsEj4pU_iRKq0X8CVpjlIi02yEgPKf8yZIIJ7Lj7D7XF_F1Wxm6r04A3TRTQQ92WJworuh4EnZM3EZSgggqQ"
expired_token := "Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjEwLCJ0ZW5hbnQiOiJjc2ljIn0.fOuIFelQOmVfndryRqeAvJIEr44rLeMt_5abqiv1621lkvoVIkAaa5zIkb2_M0-_qGgmeNFzKBFnB2gc3a5H3MWv_-TfjgufOjASg7zBRcr4P9wDoFQynWel8JXgm2WdP4_3WWJPh8yHl9FPshbfZoTbh43fb7lofCHozz8J3N9FZZD33Phz7D0N7600KzTztiRVMAGDCG1a81NT5SqCWB_k9dnh3RO4L9pIDad3fRliwC534PwgMVyYh6UaVwJz8dlwpLf2WJ8gN3nsD_t70BxtEjX0qLNRfRdBDtfpAe-BV5JY4qzVOYldYroQ6atfvX8XETe8C-gcq_oQpXtUiw"
