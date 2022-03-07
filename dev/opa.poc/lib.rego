package wac


Read = "wac:Read"
Write = "wac:Write"
Control = "wac:Control"
Append = "wac:Append"

wac_to_http = {
    Read: ["GET"],
    Write: ["POST", "PUT", "PATCH"],
    Control: ["GET", "POST", "PUT", "DELETE", "PATCH"],
    Append: ["POST", "PATCH"]
}

check(policy) {
    wacs := policy[input.tenant][input.path]
    wac_to_http[wacs[_]][_] == input.method
}
