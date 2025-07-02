import os
from google.adk.agents import LlmAgent
from google.adk.tools import VertexAiSearchTool

# --- Configuration ---
# The ADK CLI will read these from the .env file or the shell environment.
PROJECT_ID = os.environ.get("ASRR_PROJECT_ID")
LOCATION = os.environ.get("ASRR_DATASTORE_LOCATION", "global")
DATASTORE_ID = os.environ.get("ASRR_DATASTORE_ID")
MODEL = os.environ.get("ASRR_MODEL", "gemini-2.0-flash")

if not PROJECT_ID or not DATASTORE_ID:
    raise ValueError("Required environment variables ASRR_PROJECT_ID, ASRR_DATASTORE_ID are not set.")

# --- Tool Instantiation ---
full_datastore_path = f"projects/{PROJECT_ID}/locations/{LOCATION}/collections/default_collection/dataStores/{DATASTORE_ID}"
vertex_search_tool = VertexAiSearchTool(data_store_id=full_datastore_path)

# --- Agent Definition ---
# This is the agent that the ADK tool will run.
root_agent = LlmAgent(
    name="asrr_agent",
    model=MODEL,
    instruction="""You are the ASRR, an expert research assistant. 
    Use the search tool to find information in the provided documents before answering.
    Your knowledge is strictly limited to these documents.""",
    tools=[vertex_search_tool],
)