# Workshop: Kafka on your cluster

**Time:** about 80 minutes, on your own, in Cloud Shell. You need Monday's GKE cluster and your generator image. You'll run a three-broker Kafka cluster on it, stream ocean events into it, break a broker, and replay the log.

## 0. Wake the cluster up (5 min)

Your cluster has been at zero nodes since Monday. Get today's material, check Terraform, and bring the node back:

```bash
cd ~/cloud-computing-srh && git pull upstream main
terraform version                              # should print Terraform v1.9.8
cd sessions/04-docker-and-kubernetes-on-gke/starter
terraform apply                                # node_count goes back to 1
$(terraform output -raw get_credentials)
kubectl get nodes
```

If `terraform version` prints installation instructions instead of a version, follow tip 3 in the [Cloud Shell tips](../../setup/gcp.md#cloud-shell-tips) first. Without a real Terraform, `terraform apply` looks as if it worked but changes nothing, and `kubectl get nodes` finds no node.

Monday's stdout generator isn't needed any more. Remove it to free its share of the node:

```bash
kubectl delete -f k8s/generator.yaml
```

## 1. Rebuild the generator (5 min)

Today's material updates the generator's Kafka client, because Kafka 4 dropped support for old clients. Build and push it as `v2`:

```bash
PROJECT_ID=$(gcloud config get-value project)
REPO=europe-west3-docker.pkg.dev/$PROJECT_ID/freight
cd ~/cloud-computing-srh/event-generator
docker build -t $REPO/generator:v2 .
docker push $REPO/generator:v2
```

`v1` stays in the registry. Kubernetes runs whichever tag you ask for, which is why you never reuse a tag.

## 2. Install the Strimzi operator (5 min)

Kafka needs brokers, disks, certificates, configuration and careful restarts. An **operator** is a program on the cluster that knows how to do all of that: you describe the Kafka you want, and it builds and runs it.

```bash
cd ~/cloud-computing-srh/sessions/05-kafka-on-gke/starter
./install-strimzi.sh
kubectl get crd | grep strimzi
```

Those `CustomResourceDefinitions` teach Kubernetes new kinds of resource: `Kafka`, `KafkaNodePool`, `KafkaTopic` and more.

## 3. Create the Kafka cluster (10 min, part waiting)

Read `kafka/kafka-cluster.yaml` first: three nodes, each both a controller and a broker, each with its own 10 GB disk. Then:

```bash
kubectl apply -f kafka/kafka-cluster.yaml
kubectl -n kafka get pods --watch       # Ctrl+C when three freight-dual pods are Running
kubectl -n kafka wait kafka/freight --for=condition=Ready --timeout=600s
kubectl -n kafka get pvc
```

The three `PersistentVolumeClaims` are real disks in your project: find them under **Compute Engine → Disks**. They're why Kafka keeps its data when a pod restarts, or when you scale the cluster to zero tonight.

## 4. Create the topic and look at it (10 min)

```bash
sed -i "s/PROJECT_ID/$PROJECT_ID/" kafka/producer.yaml
kubectl apply -f kafka/topic-ocean-events.yaml -f kafka/client.yaml
kubectl -n kafka wait pod/kafka-client --for=condition=Ready --timeout=120s
```

Set up two shortcuts for Kafka's command-line tools, which run inside the `kafka-client` pod:

```bash
B=freight-kafka-bootstrap:9092
kk() { kubectl -n kafka exec -i kafka-client -- /opt/kafka/bin/"$1" "${@:2}"; }
```

Then describe the topic:

```bash
kk kafka-topics.sh --bootstrap-server $B --describe --topic ocean-events
```

Every partition has a **Leader** (the broker that takes its reads and writes), three **Replicas**, and an **Isr**: the in-sync replicas, the copies that are up to date. Check the retention too:

```bash
kk kafka-configs.sh --bootstrap-server $B --describe --entity-type topics --entity-name ocean-events
```

## 5. Produce, and see where events land (10 min)

Start the generator as a producer:

```bash
kubectl apply -f kafka/producer.yaml
kubectl -n kafka get pods -l app=ocean-producer
```

Read the first events back, with their key, partition and offset:

```bash
kk kafka-console-consumer.sh --bootstrap-server $B --topic ocean-events \
  --from-beginning --max-messages 10 \
  --property print.key=true --property print.partition=true --property print.offset=true
```

Kafka 4.3 warns that `--property` is deprecated. It still works, so ignore the warning.

The key is the shipment ID. Pick one from the output and find all its events in the first 200:

```bash
kk kafka-console-consumer.sh --bootstrap-server $B --topic ocean-events \
  --from-beginning --max-messages 200 \
  --property print.key=true --property print.partition=true | grep LIVE-SHP0
```

If it doesn't stop, there aren't 200 events yet: it waits for the producer to write them, which takes up to a minute and a half.

Narrow the `grep` to the shipment you picked. Every event for one shipment is on the same partition, so they stay in order. Across partitions there is no order at all.

## 6. Consumer groups and lag (10 min)

A consumer group is a team of readers that shares out the partitions and remembers how far it got. Read 50 events as the `ops-dashboard` group:

```bash
kk kafka-console-consumer.sh --bootstrap-server $B --topic ocean-events \
  --group ops-dashboard --from-beginning --max-messages 50 > /dev/null
kk kafka-consumer-groups.sh --bootstrap-server $B --describe --group ops-dashboard
```

For each partition: `CURRENT-OFFSET` is how far the group has read, `LOG-END-OFFSET` is the newest event, and `LAG` is the difference. Wait 30 seconds and describe it again: the producer keeps writing, nobody's reading, so the lag grows. Lag is the number to watch on any streaming system.

Now read as a second group, `exec-report`. It starts from the beginning on its own, and doesn't move `ops-dashboard`'s offsets:

```bash
kk kafka-console-consumer.sh --bootstrap-server $B --topic ocean-events \
  --group exec-report --from-beginning --max-messages 20 > /dev/null
kk kafka-consumer-groups.sh --bootstrap-server $B --describe --all-groups
```

## 7. Kill a broker (10 min)

Kafka keeps three copies of every partition, and accepts a write when two have it. Delete a broker while the producer is running:

```bash
kubectl -n kafka delete pod freight-dual-1
kk kafka-topics.sh --bootstrap-server $B --describe --topic ocean-events
```

Broker 1 has dropped out of the `Isr`, and any partition it led has a new leader. Is the producer still running?

```bash
kubectl -n kafka logs deployment/ocean-producer --tail=5    # the count keeps going up
kubectl -n kafka get pods --watch       # Ctrl+C when freight-dual-1 is back
kk kafka-topics.sh --bootstrap-server $B --describe --topic ocean-events
```

Once the broker is back and has caught up, it rejoins the `Isr`. Nothing was lost, and nobody restarted anything by hand.

## 8. Replay the log (10 min)

Kafka doesn't delete an event when someone reads it. It keeps every event for the topic's retention, 30 days here, and each group just remembers its position. So you can rewind a group and read everything again:

```bash
kk kafka-consumer-groups.sh --bootstrap-server $B --group ops-dashboard \
  --topic ocean-events --reset-offsets --to-earliest --execute
kk kafka-consumer-groups.sh --bootstrap-server $B --describe --group ops-dashboard
```

The lag is now the whole topic. You can also rewind to a point in time, for example to just before a bug went live:

```bash
kk kafka-consumer-groups.sh --bootstrap-server $B --group ops-dashboard \
  --topic ocean-events --reset-offsets --to-datetime 2026-11-25T17:00:00.000 --execute
```

This is the move Kappa depends on: fix your processing code, then rebuild its output by replaying the log. In session 8 you do exactly that.

## Checkpoint

Your fork contains:

- your `kafka/producer.yaml`, with your image path
- `docs/kafka.md`, with:
  - the output of `kafka-topics.sh --describe` while a broker was down
  - the output of `kafka-consumer-groups.sh --describe --group ops-dashboard` before and after the reset
  - two or three sentences: which partition did your shipment's events land on, and why are they all on the same one?
  - two or three sentences: what happened when the broker died, and why didn't the producer fail?

```bash
cd ~/cloud-computing-srh
git add sessions/05-kafka-on-gke/starter/kafka docs/kafka.md
git commit -m "Session 5: Kafka on GKE"
git push origin main
```

## Stretch

- **Two brokers down.** Delete `freight-dual-1` and `freight-dual-2` together, then try to write with `acks=all`:

  ```bash
  echo 'test' | kk kafka-console-producer.sh --bootstrap-server $B --topic ocean-events --producer-property acks=all
  ```

  What error do you get, and why is it better than accepting the write? Wait until both brokers are back before going on.
- **A compacted topic.** Create a topic `shipment-status` with `cleanup.policy: compact`, which keeps only the latest event per key. What could your ops dashboard use it for?
- **More partitions.** On a new test topic, produce keyed messages with 3 partitions, then raise it to 6 with `kafka-topics.sh --alter --partitions 6`. Do the same keys land on the same partitions as before? Why does that matter for ordering?
- **Managed or self-run?** In `docs/kafka.md`, compare running Kafka yourself with a managed service (Google Cloud's Managed Service for Apache Kafka, Confluent Cloud or Amazon MSK) for your launch customer: cost, effort, control.

## Teardown

Scale the cluster to zero. Kafka's three disks stay, with the log on them, for about €3 a month; nothing bills by the hour:

```bash
cd ~/cloud-computing-srh/sessions/04-docker-and-kubernetes-on-gke/starter
terraform apply -var node_count=0
```

Don't delete the cluster, the `kafka` namespace or the PersistentVolumeClaims: session 7 reads this topic, and session 8 replays it. Next time, `terraform apply` brings everything back with its data, and the producer carries on where it stopped. The brokers take a few minutes to come up.

## If something goes wrong

- **`freight-dual` pods stuck in `Pending`**: `kubectl -n kafka describe pod freight-dual-0` says why. `Insufficient cpu` or `Insufficient memory` means something else is using the node: check `kubectl get pods --all-namespaces` and delete Monday's generator if it's still there. No nodes at all means you skipped step 0.
- **`kubectl wait` times out**: read the operator's log, `kubectl -n kafka logs deployment/strimzi-cluster-operator --tail=50`. Most problems show up there.
- **The producer is in `CrashLoopBackOff`**: check you're running `generator:v2`, not `v1`. `kubectl -n kafka logs deployment/ocean-producer` shows the error.
- **A consumer with `--group` shows nothing**: that group has already read everything. `--from-beginning` only applies to a group that's never read before. Use a new group name, or reset its offsets.
- **`--reset-offsets` says the group is active**: a consumer in that group is still running. Stop it, wait 30 seconds, and try again.
- **`error: unable to upgrade connection`** from `kk`: the `kafka-client` pod isn't ready yet, or was deleted. Run `kubectl apply -f kafka/client.yaml` again.
- **After scaling up, the producer restarts a few times**: it starts before Kafka is ready. It settles once the brokers are up.
