# ASRR: Automated Systematic Retrieval and Review

Welcome to the ASRR Project! This repository contains the source code for an AI-powered conversational partner designed to be an expert research assistant. It leverages Google Cloud's Vertex AI Search and generative models to provide synthesized, grounded answers from a large, curated corpus of documents.

The primary goal of this project is to create an indispensable tool for researchers, architects, and scholars, enabling them to navigate and understand vast domains of information through natural language dialogue.

## Features

*   **Conversational AI**: Engage in a natural dialogue to get synthesized answers, not just search results.
*   **Grounded in Your Data**: The agent's knowledge is strictly limited to the documents you provide, ensuring answers are accurate and verifiable.
*   **Powered by Google Cloud**: Built on a scalable, serverless architecture using Vertex AI, Cloud Run, and the Google Agent Development Kit (ADK).
*   **Infrastructure as Code**: All required cloud resources are defined and managed with Terraform for easy, repeatable setup.
*   **Automated Deployment**: A single script handles service account creation, IAM permissions, and deployment to Cloud Run.

---

## Prerequisites

Before you begin, ensure you have the following installed and configured:

1.  **A Google Cloud Project**: You need a GCP project with billing enabled. You can create one [here](https://console.cloud.google.com/projectcreate).
2.  **gcloud CLI**: The Google Cloud command-line tool. [Installation Guide](https://cloud.google.com/sdk/docs/install).
3.  **Terraform**: The infrastructure as code tool. [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli).
4.  **Git**: The version control system. [Installation Guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git).

After installing the `gcloud` CLI, authenticate your session:
```sh
gcloud auth login
gcloud config set project YOUR_GCP_PROJECT_ID
```
> Replace `YOUR_GCP_PROJECT_ID` with your actual Google Cloud Project ID.

---

## Step-by-Step Deployment Guide

Follow these steps to deploy your own instance of the ASRR agent.

### Step 1: Clone the Repository

Open your terminal and clone this repository to your local machine.

```sh
git clone https://github.com/your-username/asrr.git
cd asrr
```

### Step 2: Provision Infrastructure with Terraform

We use Terraform to automatically create the necessary backend resources: a Google Cloud Storage (GCS) bucket for your documents and a Vertex AI Search data store.

1.  Navigate to the Terraform directory:
    ```sh
    cd terraform
    ```

2.  Initialize Terraform. This downloads the required providers.
    ```sh
    terraform init
    ```

3.  Apply the Terraform configuration. This will prompt you to confirm the resources that will be created.
    ```sh
    terraform apply -var="gcp_project_id=YOUR_GCP_PROJECT_ID"
    ```
    > **Note**: Replace `YOUR_GCP_PROJECT_ID` with your project ID. Type `yes` when prompted.

4.  **Save the outputs.** Once complete, Terraform will display two important values: `corpus_bucket_name` and `corpus_datastore_id`. **Copy these down**, as you will need them in the next steps.

### Step 3: Populate the Knowledge Corpus

Your agent's knowledge comes from the documents you provide.

1.  Using the Google Cloud Console or `gsutil`, upload your source documents (PDFs, TXT, HTML, etc.) to the GCS bucket whose name was output by Terraform (`corpus_bucket_name`).

2.  Vertex AI Search will automatically begin to detect, process, and index these files. This may take some time depending on the size and number of documents.

### Step 4: Configure the Agent Environment

The application needs to know which resources to connect to. This is configured using an environment file.

1.  Navigate back to the project's root directory.
    ```sh
    cd ..
    ```

2.  Create a local `.env` file by copying the provided template.
    ```sh
    cp asrr_agent/.env.example asrr_agent/.env
    ```

3.  Open `asrr_agent/.env` in a text editor and fill in the values:
    *   `GOOGLE_CLOUD_PROJECT`: Your GCP Project ID.
    *   `ASRR_PROJECT_ID`: Your GCP Project ID (this is often the same).
    *   `ASRR_DATASTORE_ID`: The `corpus_datastore_id` value you saved from the Terraform output.

    The other values can typically be left as their defaults.

### Step 5: Build and Deploy the Application

The final step is to run the deployment script. This script handles everything: creating a secure service account, assigning the correct IAM permissions, and deploying the application to Cloud Run.

1.  First, load the environment variables from your `.env` file into your current shell session.
    ```sh
    source load-env.sh
    ```

2.  Make the deployment script executable (you only need to do this once).
    ```sh
    chmod +x deploy.sh
    ```

3.  Run the script.
    ```sh
    ./deploy.sh
    ```

The deployment process will take several minutes. Once it's finished, the `gcloud` command will print the **Service URL** for your new agent.

---

## Using Your Agent

To interact with your deployed agent, take the **Service URL** from the previous step and append `/dev-ui/?app=asrr_agent` to it.

**Example URL:**
`https://asrr-agents-xxxxxxxxxx-uc.a.run.app/dev-ui/?app=asrr_agent`

Open this URL in your web browser. You will see a simple chat interface where you can begin asking questions. The agent will use the documents you uploaded to formulate its answers.

---

## How to Contribute

Contributions are welcome and greatly appreciated! Here are a few ways you can help improve the project:

*   **Report Bugs**: If you find a bug, please open an issue on GitHub.
*   **Suggest Enhancements**: Have an idea for a new feature or an improvement to an existing one? Open an issue to start a discussion.
*   **Improve Documentation**: If you find parts of the documentation unclear or incomplete, feel free to submit a pull request with your improvements.
*   **Add New Tools**: As outlined in the project's vision, the agent can be extended with new tools for more complex reasoning. This is a great area for contribution.

### Contribution Workflow

1.  Fork the repository.
2.  Create a new feature branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4.  Push to the branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

## Security

The `.env` file contains project-specific identifiers. It is included in `.gitignore` and should **never** be committed to version control. The deployment script uses a dedicated, least-privilege service account to ensure the Cloud Run service only has the permissions it absolutely needs to function.
