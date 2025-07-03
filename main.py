import os

import uvicorn
from google.adk.cli.fast_api import get_fast_api_app

# The root directory containing one or more agent subdirectories.
# The ADK will scan this directory (e.g., '/workspaces/asrr') and load any
# agent folders it finds, such as 'asrr_agent'.
AGENTS_ROOT_DIR = os.path.dirname(os.path.abspath(__file__))

# Session DB URL. Using a file-based SQLite DB is fine for Cloud Run,
# but note that container storage is ephemeral and will be lost if the instance restarts.
SESSION_DB_URL = "sqlite:///./sessions.db"

# Allowed origins for CORS. Using "*" is convenient for public access.
ALLOWED_ORIGINS = ["http://localhost", "http://localhost:8080", "*"]

# Serve the ADK's built-in web interface.
SERVE_WEB_INTERFACE = True

# Call the function to get the FastAPI app. It discovers and serves all
# agents found as subdirectories within the AGENTS_ROOT_DIR.
app = get_fast_api_app(
    agents_dir=AGENTS_ROOT_DIR,
    session_service_uri=SESSION_DB_URL,
    allow_origins=ALLOWED_ORIGINS,
    web=SERVE_WEB_INTERFACE,
)

if __name__ == "__main__":
    # Use the PORT environment variable provided by Cloud Run, defaulting to 8080
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))