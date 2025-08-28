FROM spark:3.5.1-python3
WORKDIR /opt/app
COPY spark-app/ /opt/app/
RUN if [ -f /opt/app/requirements.txt ]; then pip install --no-cache-dir -r /opt/app/requirements.txt; fi
# If you need extra Py deps, add requirements.txt and uncomment below
# COPY spark-app/requirements.txt ./
# RUN pip install --no-cache-dir -r requirements.txt
