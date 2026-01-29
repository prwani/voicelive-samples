ARG CNV_VOICE

FROM mcr.microsoft.com/azurelinux/base/nodejs:20 AS web-builder

RUN tdnf distro-sync -y && \
    tdnf install -y jq git

RUN git clone https://github.com/yulin-li/aoai-realtime-audio-sdk.git
WORKDIR /aoai-realtime-audio-sdk/javascript/standalone
RUN git checkout feature/voice-agent
RUN git checkout 11e5109528af3e29286244febc15bf0b60e3cdd6
RUN npm install && npm run build
RUN npm pack

FROM mcr.microsoft.com/azurelinux/base/nodejs:20 AS web

ARG CNV_VOICE

ENV VITE_CNV_VOICE=$CNV_VOICE

RUN tdnf distro-sync -y && \
    tdnf install -y jq && \
    tdnf clean all

COPY --from=web-builder /aoai-realtime-audio-sdk/javascript/standalone/rt-client-0.5.3.tgz /web/rt-client-0.5.3.tgz

WORKDIR /web
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM mcr.microsoft.com/azurelinux/base/python:3 AS final

RUN tdnf distro-sync -y && \
    tdnf install -y ca-certificates && \
    tdnf upgrade -y && \
    tdnf clean all

COPY --from=web /web/out /web/out
COPY app.py /web/app.py
COPY payment_api.py /web/payment_api.py
COPY db_init.py /web/db_init.py
COPY functions.py /web/functions.py
COPY phone_utils.py /web/phone_utils.py
COPY payment.html /web/payment.html
COPY view.html /web/view.html
COPY requirements.txt /web/requirements.txt

# Install Python dependencies from requirements.txt with pinned versions
# Note: Skip pip upgrade as it's managed by rpm in Azure Linux base image
RUN pip install --no-cache-dir --default-timeout=100 --retries 5 -r /web/requirements.txt

# Initialize the database
RUN python3 /web/db_init.py

# Set Python to unbuffered mode for real-time log output
ENV PYTHONUNBUFFERED=1

WORKDIR /web

EXPOSE 3000

ENTRYPOINT [ "python3", "-u", "app.py" ]