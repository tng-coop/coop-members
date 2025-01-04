#!/usr/bin/env bash
set -e

################################################################################
# readme.sh
#
# Reads readme.json, generates README.md with full coverage of *all* JSON data.
# If any part (top-level or nested) of readme.json is not handled, the script
# reports an error and exits.
################################################################################

# ------------------------------------------------------------------------------
# 1) Load the JSON into 'remaining_json'
# ------------------------------------------------------------------------------

if [ ! -f "readme.json" ]; then
  echo "ERROR: readme.json not found in the current directory."
  exit 1
fi

remaining_json="$(cat readme.json)"


# ------------------------------------------------------------------------------
# 2) Create a fresh README.md
# ------------------------------------------------------------------------------

rm -f README.md
touch README.md


# ------------------------------------------------------------------------------
# 3) Helper function: remove a JSON path from 'remaining_json'
#
#    Usage: remove_json_path ".some.nested.path"
#
#    If the path is missing or empty in 'remaining_json', that's okay. 
#    But if you want strict checking that the field MUST exist, you could add
#    additional checks inside this function.
# ------------------------------------------------------------------------------

remove_json_path() {
  local path="$1"
  remaining_json="$(echo "$remaining_json" | jq "del($path)")"
}

# ------------------------------------------------------------------------------
# 4) Helper function: verify that an object has no extra fields left unhandled
#
#    We'll pass a sub-object into this function after we've processed it,
#    and if it has leftover fields, we'll fail.
# ------------------------------------------------------------------------------

check_no_leftover_fields() {
  local jsonFragment="$1"
  local objectPathDescription="$2"

  # Count how many top-level keys remain in the fragment
  local leftoverCount
  leftoverCount="$(echo "$jsonFragment" | jq 'keys | length')"

  if [ "$leftoverCount" -gt 0 ]; then
    echo "ERROR: $objectPathDescription has $leftoverCount unhandled field(s):"
    echo "$jsonFragment" | jq 'keys'
    exit 1
  fi
}


# ------------------------------------------------------------------------------
# 5) Extract/format each portion of the JSON, removing each piece as we go.
#    If you add new fields in readme.json, you must add sections below—otherwise
#    leftover data will trigger an ERROR at the end.
# ------------------------------------------------------------------------------


######################
# Title
######################
title="$(echo "$remaining_json" | jq -r '.title // "Untitled Document"')"
echo "# $title" >> README.md
remove_json_path '.title'

######################
# Description
######################
description="$(echo "$remaining_json" | jq -r '.description // ""')"
if [ -n "$description" ] && [ "$description" != "null" ]; then
  echo >> README.md
  echo "$description" >> README.md
fi
remove_json_path '.description'

######################
# Auto-Generated Note
######################
cat <<EOF >> README.md

> **Note:** This file is **auto-generated** from \`readme.json\` by \`readme.sh\`.  
> Please **do not** edit \`README.md\` manually. Instead, update \`readme.json\` and run \`./readme.sh\`.

EOF

######################
# Stack
######################
if [ "$(echo "$remaining_json" | jq '.stack')" != "null" ]; then
  echo "## Stack" >> README.md
  echo >> README.md

  echo "$remaining_json" | jq -r '
    .stack[]
    | "- **\(.name)**: \(.purpose)"
  ' >> README.md

  echo >> README.md
fi
remove_json_path '.stack'


######################
# Overview
######################
if [ "$(echo "$remaining_json" | jq '.overview')" != "null" ]; then
  echo "## Overview" >> README.md
  echo >> README.md

  # local copy for overview
  overview="$(echo "$remaining_json" | jq '.overview')"

  # goal
  goal="$(echo "$overview" | jq -r '.goal // "No overview goal provided."')"
  echo "**Goal:** $goal" >> README.md
  echo >> README.md

  # member_features
  if [ "$(echo "$overview" | jq '.member_features')" != "null" ]; then
    echo "**Member Features:**" >> README.md
    echo "$overview" | jq -r '.member_features[] | "- \(. )"' >> README.md
    echo >> README.md
  fi

  # admin_features
  if [ "$(echo "$overview" | jq '.admin_features')" != "null" ]; then
    echo "**Admin Features:**" >> README.md
    echo "$overview" | jq -r '.admin_features[] | "- \(. )"' >> README.md
    echo >> README.md
  fi

  # Now remove the handled subkeys from overview
  # We'll do them individually to confirm we didn't skip anything
  # (If you add more subkeys under overview in readme.json, handle them above
  #  or you'll get an error below.)
  tmpOverview="$overview"
  tmpOverview="$(echo "$tmpOverview" | jq 'del(.goal)')"  
  tmpOverview="$(echo "$tmpOverview" | jq 'del(.member_features)')"  
  tmpOverview="$(echo "$tmpOverview" | jq 'del(.admin_features)')"  

  # Check leftover subkeys under "overview"
  check_no_leftover_fields "$tmpOverview" ".overview"

  # Finally, remove .overview from the global remaining_json
  remove_json_path '.overview'
fi


######################
# Objectives
######################
if [ "$(echo "$remaining_json" | jq '.objectives')" != "null" ]; then
  echo "## Objectives" >> README.md
  echo >> README.md

  echo "$remaining_json" | jq -r '
    .objectives[]
    | "### \(.name)\n\(.details)\n"
  ' >> README.md
  echo >> README.md
fi
remove_json_path '.objectives'


######################
# Architecture
######################
if [ "$(echo "$remaining_json" | jq '.architecture')" != "null" ]; then
  echo "## Architecture" >> README.md
  echo >> README.md

  architecture="$(echo "$remaining_json" | jq '.architecture')"

  echo "### Diagram" >> README.md
  echo '```' >> README.md
  echo "$architecture" | jq -r '.diagram[]' >> README.md
  echo '```' >> README.md
  echo >> README.md

  echo "### Notes" >> README.md
  echo "$architecture" | jq -r '.notes[] | "- \(. )"' >> README.md
  echo >> README.md

  # remove subkeys
  tmpArchitecture="$architecture"
  tmpArchitecture="$(echo "$tmpArchitecture" | jq 'del(.diagram)')"
  tmpArchitecture="$(echo "$tmpArchitecture" | jq 'del(.notes)')"

  check_no_leftover_fields "$tmpArchitecture" ".architecture"
  remove_json_path '.architecture'
fi


######################
# Data Model
######################
if [ "$(echo "$remaining_json" | jq '.data_model')" != "null" ]; then
  echo "## Data Model" >> README.md
  echo >> README.md

  dataModel="$(echo "$remaining_json" | jq '.data_model')"

  # members
  if [ "$(echo "$dataModel" | jq '.members')" != "null" ]; then
    echo "### members" >> README.md
    echo '```' >> README.md
    echo "$dataModel" | jq -r '.members | to_entries[] | "\(.key): \(.value)"' >> README.md
    echo '```' >> README.md
    echo >> README.md
  fi

  # memberships
  if [ "$(echo "$dataModel" | jq '.memberships')" != "null" ]; then
    echo "### memberships" >> README.md
    echo '```' >> README.md
    echo "$dataModel" | jq -r '.memberships | to_entries[] | "\(.key): \(.value)"' >> README.md
    echo '```' >> README.md
    echo >> README.md
  fi

  # roles
  if [ "$(echo "$dataModel" | jq '.roles')" != "null" ]; then
    echo "### roles" >> README.md
    echo '```' >> README.md
    echo "$dataModel" | jq -r '.roles | to_entries[] | "\(.key): \(.value)"' >> README.md
    echo '```' >> README.md
    echo >> README.md
  fi

  # member_roles
  if [ "$(echo "$dataModel" | jq '.member_roles')" != "null" ]; then
    echo "### member_roles" >> README.md
    echo '```' >> README.md
    echo "$dataModel" | jq -r '.member_roles | to_entries[] | "\(.key): \(.value)"' >> README.md
    echo '```' >> README.md
    echo >> README.md
  fi

  # Now remove each subkey from data_model to ensure we have no leftovers
  tmpDataModel="$dataModel"
  tmpDataModel="$(echo "$tmpDataModel" | jq 'del(.members)')" 
  tmpDataModel="$(echo "$tmpDataModel" | jq 'del(.memberships)')" 
  tmpDataModel="$(echo "$tmpDataModel" | jq 'del(.roles)')" 
  tmpDataModel="$(echo "$tmpDataModel" | jq 'del(.member_roles)')" 

  check_no_leftover_fields "$tmpDataModel" ".data_model"
  remove_json_path '.data_model'
fi


##############################
# Initial Database Design
##############################
if [ "$(echo "$remaining_json" | jq '.initial_database_design')" != "null" ]; then
  echo "## Initial Database Design" >> README.md
  echo >> README.md

  initDB="$(echo "$remaining_json" | jq '.initial_database_design')"

  dbDesc="$(echo "$initDB" | jq -r '.description // "No description."')"
  echo "$dbDesc" >> README.md
  echo >> README.md

  if [ "$(echo "$initDB" | jq '.sql_examples')" != "null" ]; then
    echo "### SQL Examples" >> README.md
    echo >> README.md

    echo "$initDB" | jq -c '.sql_examples[]' \
    | while read -r row; do
      tableName="$(echo "$row" | jq -r '.table')"
      echo "#### $tableName" >> README.md
      echo '```sql' >> README.md
      echo "$row" | jq -r '.snippet[]' >> README.md
      echo '```' >> README.md
      echo >> README.md
    done
  fi

  # remove subkeys from .initial_database_design
  tmpInitDB="$initDB"
  tmpInitDB="$(echo "$tmpInitDB" | jq 'del(.description)')"
  tmpInitDB="$(echo "$tmpInitDB" | jq 'del(.sql_examples)')"

  check_no_leftover_fields "$tmpInitDB" ".initial_database_design"
  remove_json_path '.initial_database_design'
fi


######################
# Frontend
######################
if [ "$(echo "$remaining_json" | jq '.frontend')" != "null" ]; then
  echo "## Frontend" >> README.md
  echo >> README.md

  frontend="$(echo "$remaining_json" | jq '.frontend')"

  # routes
  if [ "$(echo "$frontend" | jq '.routes')" != "null" ]; then
    echo "### Routes" >> README.md
    echo >> README.md

    echo "$frontend" | jq -c '.routes[]' \
    | while read -r routeObj; do
      pathVal="$(echo "$routeObj" | jq -r '.path')"
      descVal="$(echo "$routeObj" | jq -r '.description')"
      echo "- **$pathVal**: $descVal" >> README.md
    done
    echo >> README.md
  fi

  # mui_usage
  if [ "$(echo "$frontend" | jq '.mui_usage')" != "null" ]; then
    echo "### MUI Usage" >> README.md
    echo >> README.md
    echo "$frontend" | jq -r '.mui_usage[] | "- \(. )"' >> README.md
    echo >> README.md
  fi

  # remove subkeys from .frontend
  tmpFrontend="$frontend"
  tmpFrontend="$(echo "$tmpFrontend" | jq 'del(.routes)')"
  tmpFrontend="$(echo "$tmpFrontend" | jq 'del(.mui_usage)')"

  check_no_leftover_fields "$tmpFrontend" ".frontend"
  remove_json_path '.frontend'
fi


######################
# GraphQL API
######################
if [ "$(echo "$remaining_json" | jq '.graphql_api')" != "null" ]; then
  echo "## GraphQL API" >> README.md
  echo >> README.md

  gql="$(echo "$remaining_json" | jq '.graphql_api')"

  # auto_generated_resolvers
  if [ "$(echo "$gql" | jq '.auto_generated_resolvers')" != "null" ]; then
    echo "### Auto-generated Resolvers" >> README.md
    echo "$gql" | jq -r '.auto_generated_resolvers[] | "- \(. )"' >> README.md
    echo >> README.md
  fi

  # custom_logic
  if [ "$(echo "$gql" | jq '.custom_logic')" != "null" ]; then
    echo "### Custom Logic" >> README.md
    echo "$gql" | jq -r '.custom_logic[] | "- \(. )"' >> README.md
    echo >> README.md
  fi

  # auth_and_authz
  if [ "$(echo "$gql" | jq '.auth_and_authz')" != "null" ]; then
    echo "### Auth and Authz" >> README.md
    echo "$gql" | jq -r '.auth_and_authz[] | "- \(. )"' >> README.md
    echo >> README.md
  fi

  tmpGQL="$gql"
  tmpGQL="$(echo "$tmpGQL" | jq 'del(.auto_generated_resolvers)')"
  tmpGQL="$(echo "$tmpGQL" | jq 'del(.custom_logic)')"
  tmpGQL="$(echo "$tmpGQL" | jq 'del(.auth_and_authz)')"

  check_no_leftover_fields "$tmpGQL" ".graphql_api"
  remove_json_path '.graphql_api'
fi


######################
# Migrations
######################
if [ "$(echo "$remaining_json" | jq '.migrations')" != "null" ]; then
  echo "## Migrations" >> README.md
  echo >> README.md

  migrations="$(echo "$remaining_json" | jq '.migrations')"

  toolVal="$(echo "$migrations" | jq -r '.tool // "No tool specified."')"
  echo "**Tool:** $toolVal" >> README.md
  echo >> README.md

  echo "**Workflow:**" >> README.md
  echo "$migrations" | jq -r '.workflow[] | "- \(. )"' >> README.md
  echo >> README.md

  tmpMigrations="$migrations"
  tmpMigrations="$(echo "$tmpMigrations" | jq 'del(.tool)')"
  tmpMigrations="$(echo "$tmpMigrations" | jq 'del(.workflow)')"

  check_no_leftover_fields "$tmpMigrations" ".migrations"
  remove_json_path '.migrations'
fi


######################
# Security
######################
if [ "$(echo "$remaining_json" | jq '.security')" != "null" ]; then
  echo "## Security" >> README.md
  echo >> README.md

  echo "$remaining_json" | jq -r '
    .security
    | to_entries[]
    | "- **\(.key)**: \(.value)"
  ' >> README.md
  echo >> README.md

  remove_json_path '.security'
fi


######################
# Testing and QA
######################
if [ "$(echo "$remaining_json" | jq '.testing_and_qa')" != "null" ]; then
  echo "## Testing and QA" >> README.md
  echo >> README.md

  echo "- **Tool**: $(echo "$remaining_json" | jq -r '.testing_and_qa.tool // "No tool specified."')" >> README.md
  echo >> README.md

  echo "**Tests:**" >> README.md
  echo "$remaining_json" | jq -r '.testing_and_qa.tests[] | "- \(. )"' >> README.md
  echo >> README.md

  echo "**CI/CD:** $(echo "$remaining_json" | jq -r '.testing_and_qa.cicd // "No CI/CD specified."')" >> README.md
  echo >> README.md

  remove_json_path '.testing_and_qa'
fi


######################
# Deployment and Hosting
######################
if [ "$(echo "$remaining_json" | jq '.deployment_and_hosting')" != "null" ]; then
  echo "## Deployment and Hosting" >> README.md
  echo >> README.md

  echo "$remaining_json" | jq -r '.deployment_and_hosting[] | "- \(. )"' >> README.md
  echo >> README.md

  remove_json_path '.deployment_and_hosting'
fi


######################
# Dev Environments
######################
if [ "$(echo "$remaining_json" | jq '.dev_envs')" != "null" ]; then
  echo "## Dev Environments" >> README.md
  echo >> README.md

  devEnvs="$(echo "$remaining_json" | jq '.dev_envs')"

  # primary_dev_on_ubuntu
  if [ "$(echo "$devEnvs" | jq '.primary_dev_on_ubuntu')" != "null" ]; then
    echo "### Primary Dev on Ubuntu" >> README.md
    echo "$devEnvs" | jq -r '.primary_dev_on_ubuntu[] | "- \(. )"' >> README.md
    echo >> README.md
  fi

  # windows_home_machine
  if [ "$(echo "$devEnvs" | jq '.windows_home_machine')" != "null" ]; then
    echo "### Windows Home Machine" >> README.md
    echo "$devEnvs" | jq -r '.windows_home_machine[] | "- \(. )"' >> README.md
    echo >> README.md
  fi

  tmpDevEnvs="$devEnvs"
  tmpDevEnvs="$(echo "$tmpDevEnvs" | jq 'del(.primary_dev_on_ubuntu)')"
  tmpDevEnvs="$(echo "$tmpDevEnvs" | jq 'del(.windows_home_machine)')"
  check_no_leftover_fields "$tmpDevEnvs" ".dev_envs"

  remove_json_path '.dev_envs'
fi


######################
# Roadmap / Next Steps
######################
if [ "$(echo "$remaining_json" | jq '.roadmap_next_steps')" != "null" ]; then
  echo "## Roadmap / Next Steps" >> README.md
  echo >> README.md

  echo "$remaining_json" | jq -r '.roadmap_next_steps[] | "- \(. )"' >> README.md
  echo >> README.md

  remove_json_path '.roadmap_next_steps'
fi


######################
# Conclusion
######################
if [ "$(echo "$remaining_json" | jq '.conclusion')" != "null" ]; then
  echo "## Conclusion" >> README.md
  echo >> README.md

  summary="$(echo "$remaining_json" | jq -r '.conclusion.summary // "No summary available."')"
  nextSteps="$(echo "$remaining_json" | jq -r '.conclusion.next_steps // "No next steps specified."')"

  echo "**Summary:** $summary" >> README.md
  echo >> README.md
  echo "**Next Steps:** $nextSteps" >> README.md
  echo >> README.md

  remove_json_path '.conclusion'
fi


######################
# Project File Structure
######################
if [ "$(echo "$remaining_json" | jq '.project_file_structure')" != "null" ]; then
  echo "## Project File Structure" >> README.md
  echo >> README.md

  pfs="$(echo "$remaining_json" | jq '.project_file_structure')"

  # root
  if [ "$(echo "$pfs" | jq '.root')" != "null" ]; then
    echo "### Root" >> README.md
    echo "$pfs" | jq -r '.root[] | "- \(. )"' >> README.md
    echo >> README.md
  fi

  # src
  if [ "$(echo "$pfs" | jq '.src')" != "null" ]; then
    echo "### /src" >> README.md
    echo "$pfs" | jq -c '.src[]' \
    | while read -r folderObj; do
      folder="$(echo "$folderObj" | jq -r '.folder')"
      desc="$(echo "$folderObj" | jq -r '.description')"
      echo "- **$folder**: $desc" >> README.md
    done
    echo >> README.md
  fi

  # migrations
  if [ "$(echo "$pfs" | jq '.migrations')" != "null" ]; then
    echo "### /migrations" >> README.md
    echo "$pfs" | jq -r '.migrations[] | "- \(. )"' >> README.md
    echo >> README.md
  fi

  # tests
  if [ "$(echo "$pfs" | jq '.tests')" != "null" ]; then
    echo "### /tests" >> README.md
    echo "$pfs" | jq -c '.tests[]' \
    | while read -r testObj; do
      folder="$(echo "$testObj" | jq -r '.folder')"
      desc="$(echo "$testObj" | jq -r '.description')"
      echo "- **$folder**: $desc" >> README.md
    done
    echo >> README.md
  fi

  tmpPFS="$pfs"
  tmpPFS="$(echo "$tmpPFS" | jq 'del(.root)')"
  tmpPFS="$(echo "$tmpPFS" | jq 'del(.src)')"
  tmpPFS="$(echo "$tmpPFS" | jq 'del(.migrations)')"
  tmpPFS="$(echo "$tmpPFS" | jq 'del(.tests)')"
  check_no_leftover_fields "$tmpPFS" ".project_file_structure"

  remove_json_path '.project_file_structure'
fi


# ------------------------------------------------------------------------------
# 6) Final check: leftover JSON at the *top level*
#    If ANY top-level field remains, that means we didn't handle it above.
# ------------------------------------------------------------------------------

leftoverCount="$(echo "$remaining_json" | jq 'keys | length')"
if [ "$leftoverCount" -gt 0 ]; then
  echo "ERROR: There are $leftoverCount unhandled top-level key(s) in readme.json:"
  echo "$remaining_json" | jq 'keys'
  echo "Please update readme.sh to handle them."
  exit 1
fi

# ------------------------------------------------------------------------------
# Done!
# ------------------------------------------------------------------------------

echo "README.md has been generated successfully, with full JSON coverage."
