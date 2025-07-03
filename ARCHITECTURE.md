# ASRR Project: Architecture Reference

## 1. Introduction

This document provides a technical reference to the architecture of the Automated Systematic Retrieval and Review (ASRR) project. The ASRR system is an AI-powered conversational partner designed as an expert research assistant. It leverages Google Cloud's Vertex AI Search and generative models to provide synthesized, grounded answers from a user-curated corpus of documents.

The goal of this document is to describe the core components, their interactions, data flow, and deployment mechanisms to aid developers and administrators in understanding and maintaining the system.

## 2. Core Components

The ASRR system is composed of several key components, primarily leveraging Google Cloud services and the Google Agent Development Kit (ADK).

### 2.1. Google Cloud Services

*   **Google Cloud Run:** A serverless platform that hosts the ASRR agent application. It allows for scalable, stateless execution of the containerized application.
*   **Vertex AI Search:** Provides the core knowledge base.
    *   **Datastore:** Stores and indexes the document corpus, enabling semantic search capabilities.
*   **Vertex AI Platform:** Hosts and serves the generative language models (e.g., Gemini) that power the agent's conversational abilities and answer synthesis.
*   **Google Cloud Storage (GCS):** Acts as a data lake where users upload their raw documents (PDFs, TXT, HTML, etc.). These documents are then ingested by Vertex AI Search.
*   **IAM (Identity and Access Management):** Manages permissions, ensuring secure access between services. A dedicated service account with least-privilege permissions is used for the Cloud Run service.

### 2.2. ASRR Agent Application

*   **Google Agent Development Kit (ADK):** The framework used to build the agent.
    *   `LlmAgent`: The primary ADK class used in `asrr_agent/agent.py` to define the agent's behavior, selected LLM, and tools.
    *   `VertexAiSearchTool`: An ADK tool that integrates the agent directly with the Vertex AI Search datastore, allowing it to query the knowledge corpus.
*   **FastAPI:** A modern Python web framework used (via ADK's `get_fast_api_app` in `main.py`) to expose the agent's functionality as an API and to serve a built-in web interface for interaction.
*   **Uvicorn:** An ASGI server that runs the FastAPI application within the Docker container deployed on Cloud Run.

### 2.3. Infrastructure as Code

*   **Terraform:** Used to define and provision the necessary Google Cloud infrastructure (GCS bucket, Vertex AI Search datastore, API enablement) in a repeatable and version-controlled manner (`terraform/main.tf`).

### 2.4. Deployment Tools

*   **Dockerfile:** Defines the container image that packages the ASRR Python application, its dependencies, and the runtime environment.
*   **`deploy.sh` (Bash Script):** Automates the deployment of the application to Google Cloud Run. It handles service account setup, IAM permissions, and the `gcloud run deploy` command.
*   **`load-env.sh` & `.env` file:** Facilitate local environment variable management for configuration during deployment.

## 3. Architecture Diagram

The following diagram illustrates the overall architecture of the ASRR system:

```mermaid
graph TD
    subgraph "User Interaction"
        User["User"] -->|HTTPS Request via Browser| WebUI["ADK Web UI / FastAPI Endpoint"]
    end

    subgraph "Cloud Run Service (ASRR Agent)"
        WebUI -->|ASGI| App["FastAPI App (main.py)"]
        App -->|Agent Logic| Agent["ASRR Agent (agent.py, ADK LlmAgent)"]
        Agent -->|Search Query| VertexSearchTool["Vertex AI Search Tool (ADK)"]
        Agent -->|LLM Invocation| VertexAIModels["Vertex AI Generative Models (e.g., Gemini)"]
        SessionDB["SQLite (sessions.db)"] <--> App
    end

    subgraph "Google Cloud Backend"
        VertexSearchTool -->|Reads Data| VertexAIDatastore["Vertex AI Search Datastore"]
        VertexAIModels -->|Accesses Model| VertexAIP["Vertex AI Platform"]
        VertexAIDatastore <==|Indexes Data| GCSBucket["Google Cloud Storage Bucket (Corpus Documents)"]
        UserDocs["User Uploads Documents"] -->|Writes Data| GCSBucket
    end

    subgraph "Deployment & Provisioning (Developer/Admin Actions)"
        Developer["Developer/Admin"] -->|terraform apply| Terraform["Terraform (terraform/main.tf)"]
        Terraform -->|Provisions| GCSBucket
        Terraform -->|Provisions| VertexAIDatastore
        Terraform -->|Enables APIs| GCPAPIs["GCP APIs (Discovery Engine, Storage)"]

        Developer -->|git push, etc.| SourceCode["Source Code (Python, Dockerfile)"]
        SourceCode -->|./deploy.sh| DeployScript["deploy.sh"]
        DeployScript -->|gcloud run deploy| CloudBuild["Cloud Build (Implicitly builds Docker image)"]
        CloudBuild -->|Creates Image| DockerImage["Docker Image"]
        DeployScript -->|Deploys Image & Config| CloudRunService["Cloud Run Service Instance"]
        DeployScript -->|Manages| IAM["IAM Service Account & Permissions"]
        CloudRunService -->|Runs with| IAM
        CloudRunService -->|Runs| DockerImage
    end
```

## 4. Data Flow

1.  **Corpus Ingestion:**
    *   A user (Developer/Admin) uploads source documents (PDFs, TXT, etc.) to the designated **Google Cloud Storage (GCS) bucket**. This bucket is provisioned by Terraform.
    *   **Vertex AI Search** is configured to monitor this GCS bucket. It automatically detects new or updated documents, processes them, and indexes their content into the **Vertex AI Search Datastore**.

2.  **Query Processing (Runtime):**
    *   A user sends a query through the **Web UI** (served by the FastAPI application on Cloud Run).
    *   The **FastAPI application** receives the request and forwards it to the **ASRR Agent (LlmAgent)**.
    *   The ASRR Agent, using its configured instruction ("*Your knowledge is strictly limited to these documents*"), utilizes the **VertexAiSearchTool**.
    *   The `VertexAiSearchTool` queries the **Vertex AI Search Datastore** with the user's query or a transformed version of it.
    *   Vertex AI Search returns relevant snippets or documents from the indexed corpus.
    *   These search results are passed, along with the original query and agent instructions, to a **Vertex AI Generative Model** (e.g., Gemini) via the Vertex AI Platform.
    *   The generative model synthesizes an answer based *only* on the provided search results and its instructions.
    *   The synthesized answer is returned through the FastAPI application to the user via the Web UI.

## 5. Deployment Process

The deployment process involves two main phases: infrastructure provisioning and application deployment.

1.  **Infrastructure Provisioning (Terraform):**
    *   The `terraform/main.tf` script is executed by a Developer/Admin.
    *   `terraform init` initializes the Terraform environment.
    *   `terraform apply` provisions the defined Google Cloud resources:
        *   GCS bucket for the document corpus.
        *   Vertex AI Search datastore.
        *   Enables necessary Google Cloud APIs (Discovery Engine, Storage).
    *   Terraform outputs the `corpus_bucket_name` and `corpus_datastore_id`, which are needed for agent configuration.

2.  **Application Deployment (Cloud Run):**
    *   The Developer/Admin prepares the `asrr_agent/.env` file with necessary configurations (Project ID, Datastore ID from Terraform output).
    *   The `load-env.sh` script loads these environment variables into the shell session.
    *   The `deploy.sh` script is executed:
        *   It ensures a dedicated IAM service account (`asrr-agent-runner`) exists or creates it.
        *   It grants this service account the required roles (`roles/discoveryengine.viewer`, `roles/aiplatform.user`) to access Vertex AI Search and Vertex AI Platform.
        *   It invokes `gcloud run deploy --source .`, which:
            *   Uses Google Cloud Build to build a Docker image from the `Dockerfile` and current source code.
            *   Pushes the built image to Google Container Registry (or Artifact Registry).
            *   Deploys the image as a new revision to the Google Cloud Run service (`asrr-agents`).
            *   Configures the Cloud Run service with the specified service account and environment variables (passed from the `.env` file).
    *   Once deployed, Cloud Run provides a Service URL to access the agent.

## 6. Interaction Flow

1.  **Access:** The user navigates to the Service URL provided by Cloud Run, typically appending `/dev-ui/?app=asrr_agent` to access the ADK's built-in chat interface.
2.  **Query:** The user types a question or request into the chat interface and submits it.
3.  **Processing:** The request is sent to the FastAPI application running on Cloud Run. The ASRR agent processes the query as described in the "Data Flow" section (querying Vertex AI Search and using an LLM for synthesis).
4.  **Response:** The agent returns the synthesized, grounded answer, which is displayed in the chat interface.

## 7. Scalability and Maintainability

*   **Scalability:**
    *   **Cloud Run:** Inherently scalable, automatically adjusting the number of container instances based on incoming traffic.
    *   **Vertex AI Search & Platform:** Managed Google Cloud services designed for scalability.
    *   The stateless nature of the agent application (session state handled by an ephemeral SQLite DB or could be externalized) lends itself well to horizontal scaling.
*   **Maintainability:**
    *   **Infrastructure as Code (Terraform):** Ensures infrastructure is version-controlled, repeatable, and easily modifiable.
    *   **Containerization (Docker):** Provides a consistent runtime environment, simplifying deployments and reducing "works on my machine" issues.
    *   **Automation (`deploy.sh`):** Streamlines the deployment process, making it repeatable and less error-prone.
    *   **Modularity:** The agent logic (`asrr_agent/agent.py`), API serving (`main.py`), and infrastructure (`terraform/`) are separated, allowing for independent development and updates.
    *   **ADK Framework:** Provides structure and reusable components for agent development.

## 8. Security Considerations

*   **Service Account Least Privilege:** The `deploy.sh` script creates a dedicated service account for the Cloud Run service with only the necessary permissions (viewer for Discovery Engine, user for AI Platform).
*   **Environment Variables:** Sensitive information like Project IDs and Datastore IDs are managed through environment variables, with `.env` files gitignored.
*   **Cloud Run Security:** Leverages Google Cloud's security for the underlying infrastructure. Access can be further restricted using IAM and Cloud Run ingress settings.
*   **Data in GCS/Vertex AI Search:** Standard Google Cloud security measures apply to data at rest and in transit. Access to the GCS bucket and Vertex AI Datastore is controlled by IAM.

This document provides a snapshot of the ASRR project's architecture as of its current version.
