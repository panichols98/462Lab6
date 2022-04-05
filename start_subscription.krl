ruleset start_subscription {
  meta {
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subs
  }
  rule pico_ruleset_added {
    select when wrangler ruleset_installed
      where event:attr("rids") >< meta:rid
    pre {
      parent_eci = wrangler:parent_eci()
      wellKnown_eci = subs:wellKnown_Rx(){"id"}
    }
    event:send({"eci":parent_eci,
      "domain": "sensor", "type": "identify",
      "attrs": {
        "wellKnown_eci": wellKnown_eci
      }
    })
  }
}
