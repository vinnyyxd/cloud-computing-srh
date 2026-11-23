"""Carrier webhook for air shipment events.

Airlines call POST /events with one event as JSON, like a webhook. The app
checks it and publishes it to the Pub/Sub topic `air-events`, keyed by
shipment ID so each shipment's events stay in order.
"""

import json
import os

from flask import Flask, jsonify, request

PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT")  # set by App Engine
TOPIC = os.environ.get("PUBSUB_TOPIC", "air-events")
REQUIRED_FIELDS = ("event_id", "shipment_id", "event_type", "mode")

app = Flask(__name__)
_publisher = None


def publisher():
    """One Pub/Sub client per instance, created on first use."""
    global _publisher
    if _publisher is None:
        from google.cloud import pubsub_v1

        _publisher = pubsub_v1.PublisherClient(
            publisher_options=pubsub_v1.types.PublisherOptions(enable_message_ordering=True)
        )
    return _publisher


@app.get("/")
def health():
    return "carrier webhook is up\n"


@app.post("/events")
def receive_event():
    event = request.get_json(silent=True)
    if not isinstance(event, dict):
        return jsonify(error="the body must be one JSON object"), 400

    missing = [field for field in REQUIRED_FIELDS if not event.get(field)]
    if missing:
        return jsonify(error=f"missing fields: {', '.join(missing)}"), 400

    # TODO (step 3): ocean events belong on Kafka, not here. Return a 400 with
    # a clear error if event["mode"] isn't "AIR".

    client = publisher()
    topic_path = client.topic_path(PROJECT_ID, TOPIC)
    key = event["shipment_id"]
    try:
        future = client.publish(
            topic_path,
            json.dumps(event).encode(),
            ordering_key=key,
            # Attributes travel with the message; subscribers can filter on them.
            event_type=event["event_type"],
            carrier=request.headers.get("X-Carrier", ""),
            schema_version=str(event.get("schema_version", "")),
        )
        message_id = future.result(timeout=10)
    except Exception as error:
        # After a failed publish, Pub/Sub pauses that ordering key so later
        # events can't overtake the failed one. Resume it, and let the caller retry.
        client.resume_publish(topic_path, key)
        app.logger.error("publish failed for %s: %s", key, error)
        return jsonify(error="could not publish, please retry"), 503

    return jsonify(message_id=message_id), 202
