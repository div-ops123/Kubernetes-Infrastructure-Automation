# Dockerfile for both Flask app and RQ worker

# Use a lightweight Python base image
FROM python:3.8-slim

# Add metadata about the author
LABEL author="div-ops123"

# Set the container's working directory
WORKDIR /url_shortener

# Copy all project files into the container working directory
COPY . /url_shortener

# Install dependencies from requirements.txt
RUN pip install --upgrade pip && pip3 install -r requirements.txt

# Expose port 5000 for the Flask app
EXPOSE 5000