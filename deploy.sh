#!/bin/bash
#
# USE: Navigate to your project home directory. Each folder in the project home represents one agent
# and must define a root_agent in its configuration. This script deploys the agent(s) to
# Cloud Run and configures a dedicated service account with the correct permissions.

# --- Configuration ---
SERVICE_NAME="asrr-agents"
SERVICE_ACCOUNT_NAME="asrr-agent-runner"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"

# Ensure required environment variables are set in your shell before running.
# You can use `source load-env.sh` to load them from asrr_agent/.env
REQUIRED_VARS=("GOOGLE_CLOUD_PROJECT" "GOOGLE_CLOUD_LOCATION" "GOOGLE_GENAI_USE_VERTEXAI" "ASRR_PROJECT_ID" "ASRR_DATASTORE_LOCATION" "ASRR_DATASTORE_ID" "ASRR_MODEL")
for VAR in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!VAR}" ]; then
    echo "Error: Environment variable $VAR is not set." >&2
    echo "Hint: Run 'source load-env.sh' first." >&2
    exit 1
  fi
done

# --- Service Account and Permissions Setup ---
echo "Checking for service account ${SERVICE_ACCOUNT_NAME}..."
# Check if the service account already exists
if ! gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$GOOGLE_CLOUD_PROJECT" &> /dev/null; then
  echo "Service account not found. Creating..."
  gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
    --display-name="ASRR Agent Cloud Run Runner" \
    --project="$GOOGLE_CLOUD_PROJECT"
else
  echo "Service account already exists."
fi

echo "Granting Discovery Engine Viewer role to service account..."
# Grant the necessary role to the service account to allow it to search the datastore.
# This is idempotent; running it again has no effect if the binding already exists.
gcloud projects add-iam-policy-binding "$GOOGLE_CLOUD_PROJECT" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/discoveryengine.viewer" \
  --condition=None # Explicitly set no condition

echo "Granting Vertex AI User role to service account..."
# Grant the necessary role to allow the service account to invoke the Gemini model.
gcloud projects add-iam-policy-binding "$GOOGLE_CLOUD_PROJECT" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/aiplatform.user" \
  --condition=None

# --- Deployment ---
echo "Deploying service ${SERVICE_NAME} to Cloud Run..."
gcloud run deploy "$SERVICE_NAME" \
  --source . \
  --region "$GOOGLE_CLOUD_LOCATION" \
  --project "$GOOGLE_CLOUD_PROJECT" \
  --service-account "$SERVICE_ACCOUNT_EMAIL" \
  --allow-unauthenticated \
  --set-env-vars="^:^GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT:GOOGLE_CLOUD_LOCATION=$GOOGLE_CLOUD_LOCATION:GOOGLE_GENAI_USE_VERTEXAI=$GOOGLE_GENAI_USE_VERTEXAI:ASRR_PROJECT_ID=$ASRR_PROJECT_ID:ASRR_DATASTORE_LOCATION=$ASRR_DATASTORE_LOCATION:ASRR_DATASTORE_ID=$ASRR_DATASTORE_ID:ASRR_MODEL=$ASRR_MODEL"

echo "Deployment submitted. Check the Google Cloud Console for status."