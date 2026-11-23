# Workshop: the generator on your own Kubernetes cluster

**Time:** about 80 minutes, on your own, in Cloud Shell. You'll create a GKE cluster, build the event generator into a container image, and run it on the cluster.

The cluster takes about 10 minutes to create, so start it first and build the image while you wait.

## 0. Check Terraform (2 min)

Get today's material from the course repo, then check Terraform:

```bash
cd ~/cloud-computing-srh && git pull upstream main
terraform version
```

It should print `Terraform v1.9.8`. If it prints installation instructions instead, or says `command not found`, Cloud Shell's Terraform isn't a real one: follow tip 3 in the [Cloud Shell tips](../../setup/gcp.md#cloud-shell-tips) to install it in your home folder, then run `terraform version` again. Without a real Terraform, `terraform apply` looks as if it worked but creates nothing.

## 1. Start the cluster (10 min, mostly waiting)

Create the registry and the cluster:

```bash
cd ~/cloud-computing-srh/sessions/04-docker-and-kubernetes-on-gke/starter
cp terraform.tfvars.example terraform.tfvars   # set project_id
terraform init
terraform apply
```

Read the plan before you type `yes`. It creates:

- an Artifact Registry repository called `freight`, for your images
- a service account for the nodes, with only the roles they need
- a zonal GKE cluster called `freight`, with one `e2-standard-4` node (4 vCPUs, 16 GB)

Leave it running, and open a second Cloud Shell tab with **+** for the next step.

One node costs roughly 15 to 20 cents an hour. The cluster's own fee, $0.10 an hour, is covered by GKE's free tier: one zonal cluster per billing account.

## 2. Build and run the image (15 min)

The generator already has a `Dockerfile`. Read it first:

```bash
cd ~/cloud-computing-srh/event-generator
cat Dockerfile
```

Notice the order: install the dependencies first, then copy the code. Docker caches each step as a layer, so a code change doesn't reinstall everything.

Build it, then run it as a container:

```bash
docker build -t generator:v1 .
docker images generator
docker run --rm generator:v1 stream --count 5
```

The container is configured with environment variables, as it will be on Kubernetes:

```bash
docker run --rm -e MODE=air -e RATE=5 generator:v1 stream --count 10
```

`docker history generator:v1` shows the layers and their sizes. Which one is the biggest, and why?

## 3. Push it to your registry (5 min)

```bash
PROJECT_ID=$(gcloud config get-value project)
REPO=europe-west3-docker.pkg.dev/$PROJECT_ID/freight
gcloud auth configure-docker europe-west3-docker.pkg.dev
docker tag generator:v1 $REPO/generator:v1
docker push $REPO/generator:v1
```

Find the image in the console under **Artifact Registry → freight**. The registry is ready two or three minutes after `terraform apply` starts, once Terraform has switched on the APIs, so you don't have to wait for the cluster. If `docker push` fails with `failed to do request`, the registry isn't there yet: wait a minute and push again.

## 4. Connect to the cluster (5 min)

When `terraform apply` has finished, back in the first tab:

```bash
$(terraform output -raw get_credentials)
kubectl get nodes -o wide
kubectl get pods --all-namespaces
```

You see one node, and the system pods Google runs on it for logging, DNS and networking. The control plane isn't listed: Google runs it for you.

## 5. Deploy the generator (10 min)

Open `k8s/generator.yaml` and read it: a Deployment asking for one copy of your image, with the same environment variables you used in step 2. Put your project ID into the image path, then apply it:

```bash
sed -i "s/PROJECT_ID/$PROJECT_ID/" k8s/generator.yaml k8s/batch-job.yaml
kubectl apply -f k8s/generator.yaml
kubectl get pods
kubectl logs -f deployment/generator    # Ctrl+C to stop following
```

`kubectl describe pod -l app=generator` shows the events at the bottom: scheduled on your node, image pulled, container started. That's the first place to look when something doesn't start.

## 6. Watch it heal itself (5 min)

Delete the pod, and watch what happens:

```bash
kubectl delete pod -l app=generator
kubectl get pods --watch                # Ctrl+C when the new pod is Running
```

A new pod, with a new name, replaces it within seconds. You never told Kubernetes to restart anything: the Deployment says "one copy", there were none, so a controller made one. That loop, desired state against actual state, is the whole idea of Kubernetes.

## 7. Scale it (5 min)

```bash
kubectl scale deployment generator --replicas=3
kubectl get pods -o wide
kubectl logs -l app=generator --prefix --tail=3
```

Three generators, all on your one node. With more nodes, the scheduler would spread them out. Scale back to one:

```bash
kubectl scale deployment generator --replicas=1
```

## 8. Roll out a change, and roll it back (10 min)

Change the Deployment declaratively, in the file. In `k8s/generator.yaml`, set `MODE` to `air` and `RATE` to `"5"`, then:

```bash
kubectl apply -f k8s/generator.yaml
kubectl rollout status deployment/generator
kubectl logs deployment/generator --tail=5      # only air events now
kubectl rollout history deployment/generator
```

Kubernetes started a new pod with the new settings before stopping the old one. If a release goes wrong, go back:

```bash
kubectl rollout undo deployment/generator
kubectl logs deployment/generator --tail=5      # ocean and air again
```

`rollout undo` changes the cluster but not your file. The file is what you commit, so put `MODE` and `RATE` back in the file too, and apply it once more.

## Checkpoint

Your fork contains:

- your `k8s/generator.yaml`, with your image path
- `docs/kubernetes.md`, with the output of `kubectl get pods -o wide` and `kubectl rollout history deployment/generator`, and two or three sentences: what happened when you deleted the pod, and why

```bash
cd ~/cloud-computing-srh
git add sessions/04-docker-and-kubernetes-on-gke/starter/k8s docs/kubernetes.md
git commit -m "Session 4: the generator on GKE"
git push origin main
```

## Stretch

- **Run a Job.** `kubectl apply -f k8s/batch-job.yaml` runs the batch generator once. Watch it with `kubectl get jobs` and read its output with `kubectl logs job/generator-batch`. Where are the files now? The `emptyDir` volume died with the pod; next session, Kafka's data lives on disks that survive.
- **Break it on purpose.** Set the image tag to `v2`, which doesn't exist, and apply. What does `kubectl get pods` say, and what does `kubectl describe` tell you? Fix it.
- **Starve it.** Set both the memory request and the memory limit to `8Mi` and apply. (A request can't be bigger than its limit, so changing only the limit is rejected.) Find `OOMKilled` in `kubectl get pods` and in `kubectl describe pod`. Then put both back.
- **Standard or Autopilot?** Write two or three sentences in `docs/kubernetes.md`: which would you choose for your launch customer, and why?

## Teardown

Scale the cluster to zero nodes. The cluster, the registry and anything stored on disks stay, and nothing bills by the hour:

```bash
cd ~/cloud-computing-srh/sessions/04-docker-and-kubernetes-on-gke/starter
terraform apply -var node_count=0
```

Next session, `terraform apply` brings the node back. Don't run `terraform destroy`: you build Kafka on this cluster on Wednesday, and its data has to last until session 8.

## If something goes wrong

- **`Error 403: Kubernetes Engine API has not been used in project ...`**: Terraform has only just switched the API on. Wait a minute and run `terraform apply` again.
- **`Quota 'CPUS' exceeded`** or **`Quota 'SSD_TOTAL_GB' exceeded`**: something else in your project is using your quota. Look for VMs under **Compute Engine → VM instances** and delete any you don't need.
- **`ImagePullBackOff`** or **`ErrImagePull`**: the image path in `k8s/generator.yaml` is wrong, or you haven't pushed that tag. Compare it with `gcloud artifacts docker images list $REPO`.
- **`CreateContainerConfigError`** mentioning `runAsNonRoot`: keep `runAsUser: 1000` in the file. The image's user is called `app`, and Kubernetes can only check a numeric user ID.
- **Pods stuck in `Pending`**: run `kubectl get nodes`. No nodes means the cluster is scaled to zero: run `terraform apply`.
- **`kubectl` says it can't connect**, or **`gke-gcloud-auth-plugin` not found**: run the `get_credentials` command from step 4 again.
- **`no space left on device`** during `docker build`: run `docker system prune -f` and build again.
