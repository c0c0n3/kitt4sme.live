#
# Generate a test JWT token signed with the RSA key in `test_rsa_key_pair.rego`
# having a tenant field set to the `input` and an expiry date in 2286.
#
# Example
#
# $ cd deployment/mesh-infra/security/rego
# $ echo '"my-tenant"' | \
#   opa eval 'tasty_token' -I -d ./ --package 'config'
#   # ^ or equivalently
#   # opa eval 'data.config.tasty_token' -I -d ./
#   # also try appending `-f values` for less verbose output.
#

package config


import data.config.rsa_key_pair_jwk as jwk


tasty_token = t {
    header = {
        "alg": "RS256",
        "typ": "JWT"
    }
    payload = {
        "tenant": input,
        "exp": 10000000000  # 20 Nov 2286 @ 18:46:40 (CET)
    }
    jwt := io.jwt.encode_sign(header, payload, jwk)
    bearer := sprintf("Bearer %s", [jwt])

    t := {
        "bearer": bearer,
        "jwt": jwt
    }
}
