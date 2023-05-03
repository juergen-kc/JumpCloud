# Import RADIUS attributes from a CSV file
$csvFilePath = "radiusattributes.csv"
$importedAttributes = Import-Csv -Path $csvFilePath

# Convert imported attributes to JSON format
$radiusAttributes = @{
  "reply" = $importedAttributes
} | ConvertTo-Json

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
  "description": "Test Group for RADIUS CSV",
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
  "name": "Group for RADIUS testing: dynamic automated from CSV"
}
"@

# Make the POST API call to create the new group
$response = Invoke-RestMethod -Uri 'https://console.jumpcloud.com/api/v2/usergroups' -Method POST -Headers $headers -ContentType 'application/json' -Body $body
