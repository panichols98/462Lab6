ruleset sensor_profile {
  meta {
    provides profile
    shares profile
  }
  global {
    profile  = function() {
      {
        "location": ent:location,
        "name": ent:name,
        "phone": ent:phone,
        "threshold": ent:threshold || 75
      }
    }
  }
  rule update_profile {
    select when sensor profile_updated
    pre{
      location = event:attrs{"location"}.klog("new location: ")
      name = event:attrs{"name"}.klog("new name: ")
      phone = event:attrs{"phone"}.klog("new phone: ")
      threshold = event:attrs{"threshold"}.klog("new threshold")
    }
    send_directive("update_profile", {
      "location" : location,
      "name" : name,
      "phone": phone,
      "threshold": threshold
    })
    always{
      ent:location := location
      ent:name := name
      ent:phone := phone
      ent:threshold := threshold
    }
  }
}
