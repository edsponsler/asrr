# Use the Microsoft-provided dev container image for Python.
# It includes the 'vscode' user, sudo, and common dev tools like git and curl.
FROM mcr.microsoft.com/devcontainers/python:0-3.11

# Set the working directory for the container.
# The dev container will mount your project folder here.
WORKDIR /workspace

# The base image already has a 'vscode' user. We'll install tools as root before switching.
USER root

# Install system dependencies.
# - Using --no-install-recommends keeps the image smaller.
# - lsb-release is needed for adding the HashiCorp repo.
# - build-essential is for packages like PyMuPDF that may need to be compiled.
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    build-essential \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Google Cloud SDK in its own layer for better caching
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && apt-get update && apt-get install -y google-cloud-cli \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Terraform in its own layer for better caching
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update && apt-get install -y terraform \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Switch to the non-root 'vscode' user provided by the base image.
USER vscode

# Set the WORKDIR again for the non-root user context
WORKDIR /workspace

# Copy requirements file and install Python dependencies
# This leverages Docker's layer cache. If requirements.txt doesn't change, this layer won't be re-run.
COPY --chown=vscode:vscode requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code.
# The volume mount in the dev container will override this, but it's good practice for image portability.
COPY --chown=vscode:vscode . .
