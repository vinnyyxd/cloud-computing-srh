"""Where events go. Each sink takes one event dict at a time.

Kafka and Pub/Sub need extra packages: pip install -r requirements-sinks.txt
"""

import json
import sys
import urllib.request


class StdoutSink:
    def send(self, event):
        print(json.dumps(event), flush=True)

    def close(self):
        pass


class FileSink:
    def __init__(self, path):
        self.file = open(path, "a")

    def send(self, event):
        self.file.write(json.dumps(event) + "\n")

    def close(self):
        self.file.close()


class HttpSink:
    """POSTs each event as JSON, like a carrier calling a webhook."""

    def __init__(self, url, timeout=10):
        self.url = url
        self.timeout = timeout

    def send(self, event):
        request = urllib.request.Request(
            self.url, data=json.dumps(event).encode(), method="POST",
            headers={"Content-Type": "application/json", "X-Carrier": event.get("carrier") or event.get("carrier_code", "")},
        )
        try:
            urllib.request.urlopen(request, timeout=self.timeout).close()
        except Exception as error:  # keep streaming; a real carrier would retry
            print(f"http sink: {error}", file=sys.stderr)

    def close(self):
        pass


class KafkaSink:
    """Keyed by shipment ID, so one shipment's events stay in order on one partition."""

    LOG_EVERY = 20  # events between progress lines in the log

    def __init__(self, bootstrap, topic):
        try:
            from kafka import KafkaProducer
            from kafka.serializer import DefaultSerializer, JsonSerializer
        except ImportError:
            sys.exit("Kafka sink needs kafka-python: pip install -r requirements-sinks.txt")
        self.topic = topic
        self.sent = 0
        self.producer = KafkaProducer(
            bootstrap_servers=bootstrap,
            # Wait until every in-sync replica has the event before counting it as sent.
            acks="all",
            key_serializer=DefaultSerializer(),  # the shipment ID, as UTF-8
            value_serializer=JsonSerializer(),   # the event, as JSON
        )

    def send(self, event):
        self.producer.send(self.topic, key=event["shipment_id"], value=event)
        self.sent += 1
        if self.sent % self.LOG_EVERY == 0:
            print(f"kafka sink: {self.sent} events sent to {self.topic}", flush=True)

    def close(self):
        self.producer.flush()
        self.producer.close()


class PubSubSink:
    def __init__(self, topic_path):
        try:
            from google.cloud import pubsub_v1
        except ImportError:
            sys.exit("Pub/Sub sink needs google-cloud-pubsub: pip install -r requirements-sinks.txt")
        self.topic = topic_path
        self.publisher = pubsub_v1.PublisherClient()
        self.futures = []

    def send(self, event):
        self.futures.append(self.publisher.publish(
            self.topic, json.dumps(event).encode(),
            event_type=event["event_type"], mode=event["mode"],
        ))
        if len(self.futures) > 500:
            self._wait()

    def _wait(self):
        for future in self.futures:
            future.result()
        self.futures = []

    def close(self):
        self._wait()
