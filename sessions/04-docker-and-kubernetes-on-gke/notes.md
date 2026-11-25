# Session 4 notes

## Planned
- Recap of session 3: batch or stream, Lambda or Kappa, and your launch customer.
- Where today fits: the event generator on your own GKE cluster, ahead of Kafka on Wednesday.
- Virtual machines and containers.
- Docker: the Dockerfile, the image, the container and the registry.
- Images as layers, and tagging every version.
- Why one container is easy and a hundred are not: Kubernetes.
- The control loop, what's inside a cluster, and the objects you'll use.
- Requests, limits, and what goes wrong.
- GKE Standard or Autopilot, and what your cluster costs.
- Where Kubernetes earns its keep in industry.
- Workshop: build the generator's image, push it, and run it on your own cluster.

## What we covered

### This week
- Today Docker and Kubernetes; Wednesday Kafka on the same cluster. These two are harder than last week's sessions, and they're the concepts interviewers ask about most.
- Next week, Dataflow and BigQuery, and that's harder again. I'll post next week's sessions by the end of this week, so you can look ahead.
- Practise outside the sessions: build your cluster, tear it down, break it and rebuild it. You can learn Kubernetes from theory, but you only learn the nuance by doing it.
- If you've written ADR 001, send me your fork. My review is of how you reached your decision, which is what I'll look at in the assessment too. No decision is right or wrong in itself.

### Virtual machines and containers
- A virtual machine stacks server, hypervisor, a guest operating system, libraries and your application. Each VM carries a whole operating system.
- A container packs only your application and its libraries, and shares the host's operating system. You can run it anywhere a container runtime runs: your laptop, Cloud Shell, a cluster, another cloud.
- Before containers, an organisation was often tied to one operating system for everything. Containers took that choice away from the application. Still learn both Windows and Linux.
- Most applications today are containerised. Serverless is a fine option too, but at steady load, containers on a container service are usually more flexible, and cheaper as you grow.

### Docker
- Four parts: the **Dockerfile** (the recipe: base image, what to install, what to copy, what to run), the **image** you build from it, the **container** that runs the image, and the **registry** you push images to.
- In most companies you write the Dockerfile and the code; a platform team owns the rest, and a CI/CD pipeline builds and deploys every new image (week 4).
- An image is a stack of layers: a base image, the language runtime, your libraries, your code. Companies often supply a hardened, security-checked base image.
- Most problems come from the runtime and library layers, especially when you upgrade them for security fixes. New vulnerabilities turn up daily, so upgrades are constant work.
- What runs locally in a container very likely runs the same in the cloud. Not always: the cloud's infrastructure isn't yours.
- **Tag every version.** That's how you know exactly what's running. With many containers, choose a versioning strategy: everything on one version, or each team versioning its own. One version is simple, but every image is rebuilt every time, so it needs good automated tests.
- Today's flow: build in Cloud Shell, push to Artifact Registry, run on your GKE (Google Kubernetes Engine) cluster.

### Kubernetes
- One container with an application and a database is easy. A fleet is not: some containers stream, some batch, some aggregate, some watch the rest. Where does each run, what happens when one crashes at 3 a.m., and how do you add copies on a busy day?
- Kubernetes is an operating system for a fleet of machines. Every cloud also has its own container service, and many companies use those; Kubernetes runs anywhere, which is why it's worth knowing.
- **The control loop.** You declare the desired state in YAML. Controllers compare it with what's actually running and act to close the gap. Like Terraform, but it never stops checking. Nobody restarts anything by hand.
- **Inside a cluster:** a control plane (Google runs it for you on GKE) and the worker nodes your pods run on.
- **The objects:** pods, deployments and jobs today; more on Wednesday.
- **Scaling.** The desired state can change, for example more pods before a big football match. New pods take time to pull the image, start and take traffic, and time to drain. If a spike comes faster than pods can start, users notice. A common approach: over-provision by 30 to 40% at first, measure the real load for a month, then size down. Autoscaling is extra work, and your application has to cope with it too.

### Requests, limits and observability
- Each pod sets a request (what the scheduler reserves for it) and a limit (its ceiling) for CPU and memory. If no node has room for the request, the pod waits in `Pending`. Over its memory limit, the container is killed; over its CPU limit, it's slowed.
- Know your load: network, CPU and memory. In your architecture, think about what CPU and memory each kind of pod needs. Expect that question at the board.
- Containers come and go, so you can't log into a broken one afterwards. Have logs, metrics and monitoring in place before something fails. Consider observability in your design; you don't need to go deep into tracing.

### Standard or Autopilot
- **Standard:** you choose and pay for the nodes. **Autopilot:** Google manages the nodes, and you pay for what your pods request.
- Standard suits strict security or governance needs (health, government), or legacy systems on old libraries. For something new, Autopilot saves you time to spend on your logic and your tests.
- Today you use Standard, to see how it works underneath. Like learning to drive with a gear stick before an automatic.
- Your time is a resource too. An architecture has to fit the deadline and the people who'll run it. A design that needs ten new hires to support isn't a good design.

### Where Kubernetes earns its keep
- It pays off with many services run by many teams, steady load, stateful systems run by an operator (like Kafka on Wednesday), and when you want the same platform on any cloud or on-premise.
- It adds complexity. Below that, a managed service that runs containers directly may be enough.
- Moving to Kubernetes later costs more than starting with it. A common migration: build the new environment alongside the old one, test it, and move the traffic across over time.
- Kubernetes is future-proofing, and future-proofing is hard to justify at a start-up with one customer. Estimate the cost before you move.
- Companies often run both: a simple setup for prototypes, and Kubernetes for production, on separate clusters.

### Cost
- Containers are usually the biggest running cost. Scale your cluster to zero after every session: the node is what costs money. You have $300 of credit.

### Workshop
Check Terraform, start the cluster, build and push the image while it's created, deploy the generator, then delete its pod and watch it come back, scale it, and roll a change out and back. Break things on purpose: it shows you how quickly Kubernetes recovers. Cloud Shell no longer includes Terraform, so if `terraform version` prints installation instructions, follow tip 3 in the [Cloud Shell tips](../../setup/gcp.md#cloud-shell-tips). Scale to zero before you leave. The steps are in [workshop.md](workshop.md).

## Corrections to the recording
- **Terraform isn't built into Cloud Shell.** I said in the lecture that it now is. It isn't: Cloud Shell's `terraform` only prints installation instructions. Install it once in your home folder with tip 3 in the [Cloud Shell tips](../../setup/gcp.md#cloud-shell-tips), and check with `terraform version`.
- **GKE** stands for Google Kubernetes Engine.
- **Your credit is $300**, not £300.
- **Stateful systems with an operator are a good reason to use Kubernetes.** I doubted the slide in the lecture, but it's right: an operator handles the disks, restarts and upgrades a stateful system needs. Kafka with Strimzi on Wednesday is exactly that.
- **Requests and limits still matter.** I said it's mostly just requests now. Both count: the request decides where a pod can be scheduled, and the memory limit is what kills a container that uses too much. You'll see both in the workshop's Starve it stretch.

## Questions from the room
- **The control loop "closes the gap": what's the gap?** The difference between the desired state and what's running. Say you declared five pods and one goes down: the controller sees four and starts a fifth. Cloud providers react almost at once.
- **Is each pod a container?** Essentially. A pod is one or more containers that share a network; usually it's one.
- **With Kubernetes, does everything run on Google's hardware, or can we use our own?** Either. Containers run on your own machines or in any cloud; Kubernetes adds the management layer on top. That's what makes it portable, for example for software that runs on board a ship far out at sea.
- **Wouldn't running Docker and Kubernetes side by side clash?** They run on separate infrastructure in the same cloud, not on the same machines.
