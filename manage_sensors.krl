ruleset manage_sensors {
  meta {
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subs
    use module twilio-sdk alias sdk
      with
        aToken = meta:rulesetConfig{"aToken"}
        sid = meta:rulesetConfig{"sid"}
    shares sensors, managerProfile, allTemps, subscriptions
  }
  global {
    absoluteUrl = "file:///Users/parkernichols/Desktop/CS462/462Lab6/"

    sender = meta:rulesetConfig{"sender"}
    aToken = meta:rulesetConfig{"aToken"}
    sid = meta:rulesetConfig{"sid"}
    notificationNumber = meta:rulesetConfig{"to"}

    clear_sensors = { "name": "eci" }

    sensors = function() {
      ent:sensors
    }

    managerProfile = function() {
      ent:notificationNumber
    }

    subscriptions = function() {
      subs:established()
    }

    sensorProfile = function(name) {
      subs:established().map(function(mySub) {
          wrangler:picoQuery(mySub{"Tx"},"sensor_profile","profile",{})
        })
    }

    allTemps = function() {
      subs:established().map(function(mySub) {
        wrangler:picoQuery(mySub{"Tx"},"temperature_store","temps",{})
      })
    }
  }
  rule add_sensor {
    select when sensor new_sensor
    pre {
      name = event:attrs{"name"}
      exists = ent:sensors && ent:sensors >< name
    }
    if not exists then noop()
    fired {
      ent:newSensorName := name
      raise wrangler event "new_child_request"
          attributes { "name": name, "backgroundColor": "#ff69b4" }
    }
  }
  rule introduce_sensor {
    select when sensor introduction_request
    pre {
      name = event:attrs{"name"}
      wellKnown_eci = event:attrs{"wellKnown_eci"}
      eci = event:attrs{"eci"}
    }
    send_directive("about to introduce " + name);
    fired {
      ent:newSensorName := name
      ent:sensors{name} := eci
      raise sensor event "identify" attributes {"wellKnown_eci": wellKnown_eci}
    }
  }
  rule edit_manager_profile {
    select when sensor edit_profile_request
    pre {
      newNotificationNumber = event:attrs{"number"}
    }
    send_directive("updating notification number", {"number":newNotificationNumber})
    fired {
      ent:notificationNumber := newNotificationNumber
    }
  }
  rule delete_sensor {
    select when sensor unneeded_sensor
    pre {
      name = event:attrs{"name"}
      exists = ent:sensors >< name
      eci_to_delete = ent:sensors{name}{"eci"}
    }
    if exists && eci_to_delete then
      send_directive("deleting_sensor", {"name":name})
    fired {
      raise wrangler event "child_deletion_request"
        attributes {"eci": eci_to_delete};
      clear ent:sensors{name}
    }
  }
  rule trigger_sensor {
    select when sensor reading_wanted
    pre {
      name = event:attrs{"name"}
      exists = ent:sensors >< name
      childEci = ent:sensors{name}{"eci"}
    }
    if exists then
      event:send(
          { "eci": childEci,
            "eid": "sensor_reading", // can be anything, used for correlation
            "domain": "emitter", "type": "new_sensor_reading",
          }
      )
  }
  rule install_emitter {
    select when wrangler child_initialized
    pre {
      childEci = event:attrs{"eci"}
      name = event:attrs{"name"}
    }
    event:send(
        { "eci": childEci,
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": absoluteUrl,
            "rid": "emulator",
            "config": {},
          }
        }
    )
    fired {
      raise sensor event "emitter_installed"
          attributes { "childEci": childEci, "name": name }
    }
  }
  rule install_twilio {
    select when sensor emitter_installed
    pre {
      childEci = event:attrs{"childEci"}
      name = event:attrs{"name"}
    }
    event:send(
        { "eci": childEci,
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": absoluteUrl,
            "rid": "twilio-sdk",
            "config": {},
          }
        }
    )
    fired {
      raise sensor event "twilio_installed"
          attributes { "childEci": childEci, "name": name }
    }
  }
  rule install_profile {
    select when sensor twilio_installed
    pre {
      childEci = event:attrs{"childEci"}
      name = event:attrs{"name"}
    }
    event:send(
        { "eci": childEci,
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": absoluteUrl,
            "rid": "sensor_profile",
            "config": {},
          }
        }
    )
    fired {
      raise sensor event "profile_installed"
          attributes { "childEci": childEci, "name": name }
    }
  }
  rule install_store {
    select when sensor profile_installed
    pre {
      childEci = event:attrs{"childEci"}
      name = event:attrs{"name"}
    }
    event:send(
        { "eci": childEci,
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": absoluteUrl,
            "rid": "temperature_module",
            "config": {},
          }
        }
    )
    fired {
      raise sensor event "store_installed"
          attributes { "childEci": childEci, "name": name }
    }
  }
  rule install_wovyn_base {
    select when sensor store_installed
    pre {
      childEci = event:attrs{"childEci"}
      name = event:attrs{"name"}
    }
    event:send(
        { "eci": childEci,
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": absoluteUrl,
            "rid": "wovyn_base",
            "config": { "sid": sid, "aToken": aToken, "sender": sender },
          }
        }
    )
    fired {
      raise sensor event "base_installed" attributes { "childEci": childEci, "name": name }
    }
  }
  rule add_mapping {
    select when sensor base_installed
    pre {
      name = event:attrs{"name"}
      eci = event:attrs{"childEci"}
    }
    send_directive("sensor_added", {
      "name" : name,
      "eci": eci
    })
    always{
      ent:sensors := ent:sensors.defaultsTo(clear_sensors, "initialization was needed");
      ent:sensors{name} := eci
      raise sensor event "mapping_added" attributes {"name": name, "childEci": eci}
    }
  }
  rule set_profile {
    select when sensor mapping_added
    pre {
      name = event:attrs{"name"}
      eci = event:attrs{"childEci"}
    }
    event:send(
        { "eci": ent:sensors{event:attrs{"name"}},
          "eid": "profile-update", // can be anything, used for correlation
          "domain": "sensor", "type": "profile_updated",
          "attrs": {
            "phone": notificationNumber,
            "name": name,
            "location": ""
          }
        }
    )
    fired {
      raise sensor event "profile_set" attributes {"name": name, "childEci": eci}
    }
  }
  rule install_start_subscription {
    select when sensor profile_set
    pre {
      childEci = event:attrs{"childEci"}
      name = event:attrs{"name"}
    }
    event:send(
        { "eci": childEci,
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": absoluteUrl,
            "rid": "start_subscription",
            "config": {},
          }
        }
    )
  }
  rule get_profile {
    select when manager profile_requested
    pre {
      eci = ent:sensors{event:attrs{"name"}{"eci"}};
      args = {}
      answer = wrangler:picoQuery(eci,"sensor_profile","profile",{}.put(args));
    }
    if answer{"error"}.isnull() then noop();
    fired {
      // process using answer
      answer = "profile: " + answer.klog("sensor profile ")
    }
  }
  rule accept_wellKnown {
    select when sensor identify
      wellKnown_eci re#(.+)#
      setting(wellKnown_eci)
    pre {
      eci = ent:sensors{ent:newSensorName}
    }
    fired {
      ent:sensors{[ent:newSensorName,"wellKnown_eci"]} := wellKnown_eci
      ent:sensors{[ent:newSensorName,"eci"]} := eci
      raise sensor event "well_known_added" attributes {"name": ent:newSensorName}
    }
  }

  rule make_a_subscription {
    select when sensor well_known_added
    pre {
      name = event:attrs{"name"}.klog("name: ")
      sensorData = ent:sensors{name}.klog("data: ")
    }
    event:send({"eci": ent:sensors{name}{"wellKnown_eci"},
      "domain":"wrangler", "name":"subscription",
      "attrs": {
        "wellKnown_Tx":subs:wellKnown_Rx(){"id"},
        "Rx_role":"sensor", "Tx_role":"manager",
        "name":name+"-sensor", "channel_type":"subscription"
      }
    })
  }

  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    pre {
      my_role = event:attrs{"Rx_role"}
      their_role = event:attrs{"Tx_role"}
    }
    if my_role=="manager" && their_role=="sensor" then noop()
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
      ent:sensors{[ent:newSensorName,"Tx"]} := event:attrs{"Tx"}
    } else {
      raise wrangler event "inbound_rejection"
        attributes event:attrs
    }
  }

  rule receive_violation {
    select when sensor violation_sent
    pre {
      message = event:attrs{"message"}
    }
    sdk:sendText(ent:notificationNumber, sender, message)
  }

  rule clear_sensors {
    select when sensor sensors_reset
    send_directive("Clear sensors")
    always{
      ent:sensors := {}
    }
  }
}
