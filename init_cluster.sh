#!/bin/bash

# Function definitions
      # Function to check the status of all operators in the specified namespace
      check_operators_status() {
        local namespace=$1
        local statuses

        # Get the status of all operators in the namespace
        statuses=$(oc get csv -n "$namespace" -o jsonpath='{.items[*].status.phase}')

        # Check if any operator is failing
        if echo "$statuses" | grep -q "Failed"; then
          echo "Error: One or more operators are in a failed state."
          exit 1
        fi

        # Check if all operators have succeeded
        if echo "$statuses" | grep -qv "Succeeded"; then
          return 1
        fi

        return 0
      }


sh prepare_repository.sh
oc apply -f gitops/namespaces.yaml

sleep 30

# operators
oc apply -f gitops/keycloak/keycloak-operator.yaml
oc apply -f gitops/developer-hub/00_developer-hub-operator.yaml

echo "sleep for operators to get ready"
sleep 120

#TODO enable this instead of hard coded sleep
#NAMESPACE="demo-project"
#TIMEOUT=600 # Timeout after 10 minutes (600 seconds)
#SLEEP_INTERVAL=5
#echo "Checking the status of operators in the namespace '$NAMESPACE'..."
#START_TIME=$(date +%s)
#while true; do
#  if check_operators_status "$NAMESPACE"; then
#    echo "All operators have succeeded."
#    exit 0
#  else
#    CURRENT_TIME=$(date +%s)
#    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
#    if [ "$ELAPSED_TIME" -ge "$TIMEOUT" ]; then
#      echo "Error: Timeout reached. Not all operators have succeeded."
#      exit 1
#    fi
#    echo "Not all operators have succeeded yet. Checking again in $SLEEP_INTERVAL seconds..."
#    sleep $SLEEP_INTERVAL
#  fi
#done


# batch 1 (i.e. databases and pre-configurations)

  # keycloak
  oc apply -f gitops/keycloak/keycloak-postgres.yaml

  # developer hub
  oc apply -f .helper/31_developer-hub-instance-simple.yaml   # do this first, without config map links to init the database, without migration table lock issues
                                                              # TODO this bug should be solved, should not be required
  oc apply -f gitops/developer-hub/01_secret.yaml
  oc apply -f gitops/developer-hub/11_app-config-rhdh.yaml
  oc apply -f gitops/developer-hub/21_dynamic-plugins-rhdh.yaml

echo "sleep for batch 1 to get ready"
sleep 300

# batch 2 (i.e. instances)

  # keycloak
  oc apply -f gitops/keycloak/keycloak-instance.yaml

echo "sleep for batch 2 to get ready"
sleep 300

# batch 3 (i.e. configs)

  # keycloak
  oc apply -f gitops/keycloak/keycloak-realm.yaml

echo "sleep for batch 3 to get ready"
sleep 300

# batch 4

  # developer hub
  oc apply -f gitops/developer-hub/31_developer-hub-instance.yaml

