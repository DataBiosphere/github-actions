FROM openpolicyagent/conftest:v0.24.0

COPY ./policy /policy

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
