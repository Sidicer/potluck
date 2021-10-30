#!/bin/sh
cat /mnt/metricscerts/metricsca.crt /mnt/metricscerts/ca_root.crt \
  >/mnt/metricscerts/ca_chain.crt.tmp
# might be different for loki and prometheus, or need all
chown nodeexport /mnt/metricscerts/*
mv /mnt/metricscerts/ca_chain.crt.tmp /mnt/metricscerts/ca_chain.crt

# only need node_exporter restarted on consul-tls node for metrics certs
service node_exporter restart

exit 0