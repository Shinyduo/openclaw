# Thin wrapper over the official OpenClaw image.
# Only job: make the root-owned Railway volume writable by the image's
# non-root `node` user (uid 1000), then hand off to the upstream entrypoint.
FROM openclaw/openclaw:2026.6.34

USER root

# Upstream ends on `USER node`, so Docker would set HOME=/home/node. Switching
# back to root flips it to /root, which uid 1000 cannot write. Pin it.
ENV HOME=/home/node

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["node", "openclaw.mjs", "gateway"]
