ruleset temperature_store {
  meta {
    use module sensor_profile alias sensor_profile
    provides temps, threshold_violations, inrange_temperatures
    shares temps, threshold_violations, inrange_temperatures
  }
  global {
    clear_temp = { "timestamp": "temp" }

    temps = function() {
      ent:temps
    }

    threshold_violations = function() {
      ent:violations
    }

    inrange_temperatures = function() {
      ent:temps.filter(function(v,k){v{"temperatureF"} <= sensor_profile:profile(){"threshold"}})
    }
  }
  rule collect_temperatures {
    select when wovyn new_temperature_reading
    pre{
      passed_timestamp = event:attrs{"time"}.klog("our passed in timestamp: ")
      passed_temperature = event:attrs{"temp"}.klog("our passed in temperature: ")
    }
    send_directive("store_temp", {
      "time" : passed_timestamp,
      "temp" : passed_temperature
    })
    always{
      ent:temps := ent:temps.defaultsTo(clear_temp, "initialization was needed");
      ent:temps{passed_timestamp} := passed_temperature
    }
  }
  rule collect_threshold_violations {
    select when wovyn threshold_violation
    pre{
      passed_timestamp = event:attrs{"time"}.klog("our passed in violation timestamp: ")
      passed_temperature = event:attrs{"temp"}.klog("our passed in violation temperature: ")
    }
    send_directive("store_violation", {
      "time" : passed_timestamp,
      "temp" : passed_temperature
    })
    always{
      ent:violations := ent:violations.defaultsTo(clear_temp, "initialization was needed");
      ent:violations{passed_timestamp} := passed_temperature
    }
  }
  rule clear_temperatures {
    select when sensor reading_reset
    send_directive("Clear temperatures")
    always{
      ent:violations := clear_temp
      ent:temps := clear_temp
    }
  }
}
