FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive
# Set platform for multi-arch builds (Docker Buildx will set this)
ARG TARGETPLATFORM
ARG NODE_MAJOR=20

RUN apt-get update && apt-get install -y \
    xvfb \
    wget git curl unzip \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libxcomposite1 libxdamage1 libxrandr2 \
    fonts-liberation fontconfig \
 && rm -rf /var/lib/apt/lists/*

# Install noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc \
    && git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify \
    && ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# Install Node.js using NodeSource PPA
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install nodejs -y \
    && rm -rf /var/lib/apt/lists/*

# Verify Node.js and npm installation (optional, but good for debugging)
RUN node -v && npm -v && npx -v

# Set up working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
# Ensure 'patchright' is in your requirements.txt or install it directly
# RUN pip install --no-cache-dir -r requirements.txt patchright # If not in requirements
RUN pip install --no-cache-dir -r requirements.txt

# Install Patchright browsers and dependencies
# Patchright documentation suggests PLAYWRIGHT_BROWSERS_PATH is still relevant
# or that Patchright installs to a similar default location that Playwright would.
# Let's assume Patchright respects PLAYWRIGHT_BROWSERS_PATH or its default install location is findable.
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-browsers
RUN mkdir -p $PLAYWRIGHT_BROWSERS_PATH

# Install recommended: Google Chrome (instead of just Chromium for better undetectability)
# The 'patchright install chrome' command might download and place it.
# The '--with-deps' equivalent for patchright install is to run 'patchright install-deps chrome' after.
# RUN patchright install chrome --with-deps

# Alternative: Install Chromium if Google Chrome is problematic in certain environments
RUN patchright install chromium --with-deps

# Copy the application code
COPY . .

# Set up supervisor configuration
RUN mkdir -p /var/log/supervisor
# we only need to expose the WebUI port (Railway sets $PORT for us)
EXPOSE 7788

CMD ["sh", "-c", \
    "xvfb-run --auto-servernum --server-args='-screen 0 1920x1080x24' \
       python webui.py --ip 0.0.0.0 --port $PORT"]
