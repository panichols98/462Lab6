ruleset twilio-sdk {
  meta {
    configure using
      aToken = ""
      sid = ""
    provides sendText, getMessages
  }

  global {
    base_url = "https://api.twilio.com/"

    sendText = defaction(to, sender, message) {
      authMap = { "username": sid,  "password": aToken }.klog("authMap")
      body = {"To": to, "From": sender, "Body": message}.klog("body")
      http:post(<<#{base_url}/2010-04-01/Accounts/#{sid}/Messages>>
        ,auth=authMap,form=body) setting(response)
      return response
    }

    getMessages = defaction(recipient, sender, pages) {
      qStrings = {}.put((recipient) => {"To": recipient} | {});
      senderMap = {}.put((sender) => {"From": sender} | {});
      toAndFrom = qStrings.put(senderMap)
      finalqs = toAndFrom.put((pages) => {"PageSize": pages} | {});
      authMap = { "username": sid,  "password": aToken }.klog("authMap")
      http:get(<<#{base_url}/2010-04-01/Accounts/#{sid}/Messages>>
        ,auth=authMap, qs=finalqs, autoraise = "twilio") setting(response)
      return response
    }
  }
}
