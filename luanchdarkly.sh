#!/bin/bash



echo "Enter complete path for cluster list ex: users/user/canaries-devel.json"
read cluster_list_path
echo "Enter config name ex: test.config.enable"
read config_name
echo "Enter environment ex: prod/devel/stag"
read environment
echo "Enter authorization key"
read -s authorization_key
echo "Enter config value"
read flag_value


clusters="$(cat $cluster_list_path)"


internal_canaries="$(echo $clusters | jq '.clusters.internal_canaries' | awk '{printf("%s",$0)} END { printf "\n" }')"
external_canaries="$(echo $clusters | jq '.clusters.external_canaries' | awk '{printf("%s",$0)} END { printf "\n" }')"
phase_n_canaries="$(echo $clusters | jq '.clusters.phase_n_canaries' | awk '{printf("%s",$0)} END { printf "\n" }')"

echo "Fecthing config details ${external_canaries}"
flag_details="$(curl -X GET 'https://app.launchdarkly.com/api/v2/flags/default/'${config_name} -H 'Authorization: '${authorization_key} | jq)"

echo "Sucessfully got the config details"


variation_id="$(echo $flag_details | jq ".variations[] | select(.value==$flag_value) | ._id")"


rule_id="$(echo $flag_details | jq '.environments.'${environment}'.rules[] | select(.description=="'${description}'") | ._id')"

if [ -n "$rule_id" ]; then

echo "Found existing rule with description ${description}"

delete_rule="$(curl -X PATCH \
  'https://app.launchdarkly.com/api/v2/flags/default/'${config_name} \
  -H 'Authorization: '${authorization_key} \
  -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
  -d '{
        "environmentKey": "'${environment}'",
        "instructions": [
          {
            "kind": "removeRule",
            "ruleId": '${rule_id}'
          }
        ]
      }
 ')"

echo "Deleted existing rule with description ${description}"

fi

echo "Creating new rule with external canaries cluster"


add_rule="$(curl -X PATCH \
  'https://app.launchdarkly.com/api/v2/flags/default/'${config_name} \
  -H 'Authorization: '${authorization_key} \
  -H 'Content-Type: application/json; domain-model=launchdarkly.semanticpatch' \
  -d '{
        "comment": "",
        "environmentKey": "'${environment}'",
        "instructions": [
          {
            "kind": "addRule",
            "clauses": [
              {
                "attribute": "cluster.id",
                "op": "in",
                "values": '${external_canaries}',
                "negate": false
              }
            ],
            "variationId": '${variation_id}',
            "description": "'${description}'"
          }
        ]
      }')"

echo "Created new rule for external canaries cluster"


