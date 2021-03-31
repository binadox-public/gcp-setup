#!/usr/bin/env bash

####################################################################################################
# This script enables Binadox-required GCP services and creates a custom IAM role used by
# the Binadox.
#
# Configurable params:
# $ROLE_DESTINATION — determines where the role must be created. Supported values are `project`
# and `org`.
#
# $ORG_ID — holds the GCP organization ID. Is only used when `$ROLE_DESTINATION` is equal to `org`.
# $DEVSHELL_PROJECT_ID — holds the GCP project ID.
#
####################################################################################################

# Holds the GCP Project ID. Defaults to the GCloud Console default project ID.
PROJECT_ID="${DEVSHELL_PROJECT_ID}"

########## The part below enabled required GCP APIs and services.

# Defines the set of services that must be enabled.
GCP_SERVICES="\
compute.googleapis.com \
bigquery.googleapis.com \
bigquerydatatransfer.googleapis.com \
bigquerystorage.googleapis.com \
monitoring.googleapis.com \
admin.googleapis.com \
bigtable.googleapis.com \
bigtableadmin.googleapis.com \
pubsub.googleapis.com \
cloudresourcemanager.googleapis.com \
sqladmin.googleapis.com \
storage.googleapis.com \
"
echo "Enabling required services."
# shellcheck disable=SC2086
# we want the split the items
gcloud services enable $GCP_SERVICES --project="${PROJECT_ID}"

########## The part below creates a custom IAM role.

# The ID of the custom IAM role used by the Binadox services.
ROLE_ID="BinadoxBillingConfigurer"
# Determines whether the role is created on the Project or Organization level. Defaults to `project`.
ROLE_DESTINATION="${ROLE_DESTINATION:-project}"
# Holds the GCP Organization ID. Must be explicitly configured by the caller.
ORG_ID="${ORG_ID}"
# Defines the role description available in the UI.
ROLE_DESCRIPTION="Allows Binadox Billing configurer to access and label required resources."
# Defines the human-friendly title of the role
ROLE_TITLE="Binadox Billing Configurer"
# Defines the readiness of the configured role.
ROLE_STAGE="BETA"
# Defines the set of permissions granted to the actor on whom the role is assigned.
ROLE_PERMISSIONS="\
bigquery.datasets.get,\
bigquery.datasets.update,\
bigquery.jobs.create,\
bigquery.tables.getData,\
bigquery.tables.list,\
bigtable.instances.get,\
bigtable.instances.list,\
bigtable.instances.update,\
cloudsql.databases.list,\
cloudsql.databases.update,\
cloudsql.instances.list,\
cloudsql.instances.update,\
compute.disks.list,\
compute.disks.setLabels,\
compute.instances.useReadOnly,\
compute.instances.get,\
compute.instances.list,\
compute.instances.setLabels,\
compute.snapshots.get,\
compute.snapshots.list,\
compute.snapshots.setLabels,\
pubsub.subscriptions.list,\
pubsub.subscriptions.update,\
pubsub.topics.list,\
pubsub.topics.update,\
storage.buckets.get,\
storage.buckets.list,\
storage.buckets.update"

if [[ "${ROLE_DESTINATION}" == "org" ]]; then
  DESTINATION="--organization=${ORG_ID}"
else
  DESTINATION="--project=${PROJECT_ID}"
fi

gcloud iam roles describe "${ROLE_ID}" --quiet "${DESTINATION}" 2>/dev/null
ROLE_EXISTS=$?

if [[ $ROLE_EXISTS -eq 0 ]]; then
  echo "Updating existing '${ROLE_ID}' role on '${ROLE_DESTINATION}' level."
  IAM_COMMAND="gcloud iam roles update"
else
  echo "Creating a new '${ROLE_ID}' role on '${ROLE_DESTINATION}' level."
  IAM_COMMAND="gcloud iam roles create"
fi

$IAM_COMMAND "${ROLE_ID}" \
  "${DESTINATION}" \
  --description="${ROLE_DESCRIPTION}" \
  --title="${ROLE_TITLE}" \
  --stage="${ROLE_STAGE}" \
  --permissions="${ROLE_PERMISSIONS}"


########## The part below creates a service account.

SERVICE_ACCOUNT_NAME="binadox-configurer"
SERVICE_ACCOUNT_DESCRIPTION="Allows Binadox configurer to label and analyze resources."
SERVICE_ACCOUNT_DISPLAY_NAME="Binadox Configurer"

SERVICE_ACCOUNT_ID="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Creating a service account."

gcloud iam service-accounts create "${SERVICE_ACCOUNT_NAME}" \
  --description="${SERVICE_ACCOUNT_DESCRIPTION}" \
  --display-name="${SERVICE_ACCOUNT_DISPLAY_NAME}" \
  --project="${PROJECT_ID}"


if [[ "${ROLE_DESTINATION}" == "org" ]]; then
  ROLE_NAME="organizations/${ORG_ID}/roles/${ROLE_ID}"
else
  ROLE_NAME="projects/${PROJECT_ID}/roles/${ROLE_ID}"
fi

echo "Updating service account roles."

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT_ID}" \
  --role="${ROLE_NAME}"
