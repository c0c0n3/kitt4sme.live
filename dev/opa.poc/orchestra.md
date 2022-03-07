Orchestra OPA
-------------
> Notes collected from various discussions on the topic.

**NOTE**. What's documented below refers to how Orchestra OPA used
to work mid Jan 2022. The product has changed alot since, so we
should evaluate it again!


Code at:

- https://github.com/orchestracities/opa-authz

So that's how Orchestra OPA works at a very high-level.

1. client sends HTTP request `r`
2. envoy intercepts and passes `r` on to OPA service
3. OPA extracts request fields into JSON input doc `j(r)`
4. OPA evaluates `policy.rego` (file in `config/opa-service/`;
   the file gets mounted on the OPA pod, see Docker compose in
   repo root)
5. code in `policy.rego` fetches policy data for the tenant
   in `j(r)` from policy server
6. policy server retrieves tenant's policy data from DB and returns
   it as a JSON object (`data.json`) with user, group and role permissions
7. code in `policy.rego` feeds `data.json` into service policy rules
   and returns decision to OPA---rules are tied to a specific service
   API, so there's a `policy.rego` for each service to protect: one
   for Orion, one for Agents, etc.
8. envoy denies or forwards `r` to target service based on decision

```
        r       r      j(r)             tenant
client --> env --> opa ---> policy.rego ------> policy server ----> DB
                      <-----           <------
                     decision          data.json
```

Potential issues w/ the approach

* Performance. Every policy decision entails an external API call which
  in turn makes (one or more?) DB calls. So every service secured using
  this approach will have increased latency on each and every service
  call. TODO we should benchmark to see if this is a price we can pay
  though---e.g. what if the added latency is just a couple of ms?
  Wouldn't that be acceptable? Also, OPA might cache HTTP calls and
  decisions.
* Extensibility.
  - How to extend the data returned by the policy server w/ new fields?
    NOTE the format is quite generic (WAC) though so we might not need
    to extend it
  - How to write and test your own policy to extend an existing one?
    e.g. how to import `policy.rego` in another Rego file which adds
    an extra rule
* Complexity. Isn't the extra policy server and DB going to add to
  the complexity of our deployment? Is there any compelling reason
  to swap out the standard Envoy/OPA/Rego setup?


Current KITT4SME approach

1. client sends HTTP request `r`
2. envoy intercepts and passes `r` on to OPA service
3. OPA extracts request fields into JSON input doc `j(r)`
4. OPA evaluates service policy in `data.rego` (the equivalent of
   `data.json`) which imports `lib.rego` (generic rules)---everything
   happens in Rego so you can easily compose and extend rules as
   well as factoring out common functionality
5. Rego code returns decision to OPA
6. envoy denies or forwards `r` to target service based on decision

```
        r       r      j(r)
client --> env --> opa -----> data.rego + lib.rego
                      <-----
                     decision
```

Rego files gets mounted on OPA pods automatically during deployment.
All Rego code sits in the KITT4SME repo and can be easily developed
and tested as you'd do e.g. in Python. When you commit, the code gets
automatically deployed to the OPA pods.

TODO

Talk about PoC in this dir

```console
$ opa eval -d policy.rego -d lib.rego -i input.json 'data'
```

```console
$ opa eval -d policy.rego -d lib.rego -i input.json 'data.policy.allow'
```
