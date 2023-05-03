# Define RADIUS attributes and values as a custom object
$radiusAttributes = @"
{
  "reply": [
    {"name": "Service-Type", "value": "Framed-User"},
    {"name": "Framed-Protocol", "value": "PPP"},
    {"name": "Framed-IP-Address", "value": "192.168.1.100"},
    {"name": "Framed-IP-Netmask", "value": "255.255.255.0"},
    {"name": "Framed-Routing", "value": "None"},
    {"name": "Filter-Id", "value": "example-filter"},
    {"name": "Framed-MTU", "value": "1500"},
    {"name": "Framed-Compression", "value": "Van-Jacobson-TCP-IP"},
    {"name": "Login-IP-Host", "value": "192.168.1.2"},
    {"name": "Login-Service", "value": "Telnet"},
    {"name": "Login-TCP-Port", "value": "23"},
    {"name": "Reply-Message", "value": "Welcome to the network!"},
    {"name": "Callback-Number", "value": "555-1234"},
    {"name": "Callback-Id", "value": "cb123"},
    {"name": "Framed-Route", "value": "192.168.2.0/24 192.168.1.1 1"},
    {"name": "Framed-IPX-Network", "value": "00000001"},
    {"name": "State", "value": "0x0123456789abcdef"},
    {"name": "Class", "value": "0x010203040506"},
    {"name": "Session-Timeout", "value": "3600"},
    {"name": "Idle-Timeout", "value": "1800"},
    {"name": "Termination-Action", "value": "Default"},
    {"name": "Called-Station-Id", "value": "00-11-22-33-44-55"},
    {"name": "Calling-Station-Id", "value": "00-66-77-88-99-AA"},
    {"name": "NAS-Identifier", "value": "nas-001"},
    {"name": "Proxy-State", "value": "0x9876543210abcdef"},
    {"name": "Login-LAT-Service", "value": "LAT service name"},
    {"name": "Login-LAT-Node", "value": "LAT node name"},
    {"name": "Login-LAT-Group", "value": "LAT group name"},
    {"name": "Framed-AppleTalk-Link", "value": "1"},
    {"name": "Framed-AppleTalk-Network", "value": "65280"},
    {"name": "Framed-AppleTalk-Zone", "value": "Zone 1"}
  ]
}
"@



# Define API headers
$headers = @{
  "x-org-id" = "YOUR_ORG_ID"
  "x-api-key" = "YOUR_API_KEY"
  "content-type" = "application/json"
}

# Define API body with the custom RADIUS attributes object
$body = @"
{
  "attributes": {
    "radius": $radiusAttributes
  },
  "description": "Test Group for RADIUS",
  "email": "test@example.com",
  "memberQuery": {
    "queryType": "FilterQuery",
    "filters": [
      {
        "field": "email",
        "operator": "eq",
        "value": "test@example.com"
      }
    ]
  },
  "memberQueryExemptions": [],
  "memberSuggestionsNotify": true,
  "membershipAutomated": true,
  "membershipMethod": "DYNAMIC_AUTOMATED",
  "name": "Group for RADIUS testing: dynamic automated"
}
"@



# Make the POST API call to create the new group
$response = Invoke-RestMethod -Uri 'https://console.jumpcloud.com/api/v2/usergroups' -Method POST -Headers $headers -ContentType 'application/json' -Body $body
