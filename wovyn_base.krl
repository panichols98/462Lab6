ruleset wovyn_base {
  meta {
    use module sensor_profile alias sensor_profile
    use module io.picolabs.subscription alias subs
    /* use module twilio-sdk alias sdk
      with
        aToken = meta:rulesetConfig{"aToken"}
        sid = meta:rulesetConfig{"sid"} */

    shares threshold
  }
  global {
    sender = meta:rulesetConfig{"sender"}

    lastResponse = function() {
      {}.put(ent:lastTimestamp,ent:lastResponse)
    }

    threshold = function() {
      sensor_profile:profile(){"threshold"}
    }
  }
  rule process_heartbeat {
    select when wovyn heartbeat where event:attrs{"genericThing"}
    pre {
      temp = event:attrs{"genericThing"}{"data"}{"temperature"}[0].klog("temp")
      time = time:now()
      temp_map = {}.put("temp", temp)
      attribute_map = temp_map.put("time", time)
    }
    fired {
      raise wovyn event "new_temperature_reading" attributes attribute_map
    }
  }
  rule find_high_temps {
    select when wovyn new_temperature_reading
    send_directive("current temp: " + event:attrs{"temp"}{"temperatureF"})
    fired {
      raise wovyn event "threshold_violation" attributes event:attrs
        if (event:attrs{"temp"}{"temperatureF"} > sensor_profile:profile(){"threshold"})
    }
  }
  rule threshold_notification {
    select when wovyn threshold_violation
    pre {
      managerSubs = subs:established().filter(function(x){x{"Tx_role"} == "manager"})
      managerSub = managerSubs[0]
      name = sensor_profile:profile(){"name"}
      message = name + " Temperature violation: " + event:attrs{"temp"}{"temperatureF"}
    }
    event:send({"eci": managerSub{"Tx"},
      "domain":"sensor", "name":"violation_sent",
      "attrs": {
        "message": message
      }
    })
    /* pre {
      message = "Temperature violation: " + event:attrs{"temp"}{"temperatureF"}
      message_log = message.klog("text message")
    }
    sdk:sendText(sensor_profile:profile(){"phone"}, sender, message) setting(response)
    fired {
      ent:lastResponse := response
      ent:lastTimestamp := time:now()
    } */
  }
}
