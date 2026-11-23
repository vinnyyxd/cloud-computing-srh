# Session 3 notes

## Planned
- Recap of sessions 1 and 2: what you've built so far on Google Cloud.
- The terms we use for the companies: your company, shippers, carriers, your launch customer, lanes.
- Batch and stream processing, and choosing freshness by what the user needs.
- Event time versus processing time.
- The Lambda and Kappa architectures, with examples outside freight, and when each fits.
- The reference platform you'll build over the next four weeks.
- Architecture decision records (ADRs).
- Workshop: fork the repo, get your launch customer, measure delay per lane, sketch your architecture, and write ADR 001.

## What we covered

### Recap: what you've built
- Session 1: a Google Cloud project inside an organisation, IAM around it, and a Cloud Storage bucket created with Terraform. You gave your neighbour access through IAM.
- IAM has two kinds of permission: for people (user accounts) and between applications (service accounts).
- Session 2: the generator's CSV files land in Cloud Storage, an object store that's cheap, scalable and durable. BigQuery is a compute layer on top of storage: it runs your SQL against those files. That was your first data pipeline.
- Terraform: `main.tf`, `variables.tf` and `outputs.tf` on your machine; `terraform plan` and `terraform apply` deploy them to the cloud.
- Cloud platforms are layers on layers. In most organisations the lower layers are someone else's problem. Yours is what you build on top, and IAM: only you know what your application needs access to.

### The terms we use
- **Your company:** a freight data analytics company. You're its architect.
- **Shippers:** businesses that move goods from one place to another, and pay by the container. Different industries care about different things: a pharmaceutical shipper cares about transit time and reliability; a shipper of cotton cares more about cost and volume.
- **Carriers:** the companies that own the ships and the lines. Shippers buy space from them.
- **Launch customer:** the first big customer your platform is built for. Start-ups build for a small group of customers first and grow from there. You don't all have the same one, so you won't all have the same answers.
- **Lane:** origin to destination, port to port, for example Ningbo to Hamburg.
- Your customer profile is short on purpose. You can add to it: list your assumptions, and tie your decisions back to them.

### Batch and stream
- **Batch** data has an end. You process it chunk by chunk. It's cheaper and more complete, and it's usually about the past: how a container price changed over three years is a batch report.
- **Stream** data doesn't end. It's for the most recent value, for example the latest price for a booking you're placing today. It's more expensive, because it needs compute running all the time.
- Bounded and unbounded data are the academic names for the same split. You'll rarely hear them at work.
- Rule of thumb: anything measured in minutes or longer can be batch. Streaming is for seconds. Batch has become fast and cheap enough that the two are merging: most companies run a mix on serverless services that scale up and down, and managed platforms ask you only for the source, the destination, the schemas and how often to refresh. Still know what's underneath, so you know what you're paying for.
- Very little needs to be real-time. Even in shipping, the last hour is usually enough. Formula 1 telemetry, where a tenth of a second matters, is the exception. Anything refreshed more often than about once an hour gets harder to maintain.

### Event time and processing time
- An event happens at one time and is processed at another. Build your tables on event time; most time-series data carries it.
- If the customer needs an event from 10:00 by 10:05, your pipeline has to process it in under 5 minutes, and better in 2, to leave room for load spikes.
- Build in slack. If the customer needs data by 13:00, aim to have it in the warehouse by 12:00 in case a job fails or there's an unusual volume that day.
- Plan for the pipeline going down: you need to be able to catch up quickly.

### Lambda and Kappa
- **Lambda:** two pipelines, a batch layer and a speed layer. It's been the norm for a long time, chosen for flexibility and as a backup: if the speed layer goes down, the batch layer still delivers. The hard part is keeping the two in sync; for example, rounding differences between events and hourly aggregates.
- **Kappa:** one streaming pipeline, plus the ability to replay the log. Most new platforms are built this way, because the cloud providers have made it easier, and one well-built pipeline isn't weaker than two. The hard part is the log: it has to be durable, stored in the right place, and replayable. A badly built replay can lose data for good.
- Keep raw data immutable: land it in a raw bucket first, then build processed layers on top. A stream job logs what it received, when it started and finished, where it read from and where it wrote. If the pipeline stops at 15:00, you find the gap in the log and replay from there.
- Examples: Lambda for card payments and online shopping on Black Friday. The speed layer gives the bare minimum, such as how many TVs have sold; the batch layer adds the rest, such as which countries they sold in, for reporting later. Kappa for smart meters and most IoT, where everything is an event.
- At work most people just say "batch and streaming". Lambda and Kappa are the textbook names; they're worth knowing for interviews.
- Watch for hype cycles: virtualisation, cloud, microservices, event-driven, now AI. Architects over-build to stay ahead of the trend, and it costs the company. Choose what the customer needs.

### The reference platform
- This is what you'll build over the next four weeks, piece by piece. You've already built the first two pieces.
- Batch layer: rate and schedule files into Cloud Storage, processed by Dataproc (Spark), into curated BigQuery tables. Rates and schedules are less urgent than shipment events, so different datasets get different pipelines.
- Speed layer: an event generator next session, then Kafka on Kubernetes for ocean freight (best in class and robust, but expensive), and a cheaper path for air freight. Both feed Dataflow and land in BigQuery for the ops dashboard by session 7.
- Session 10 adds more Terraform, monitoring and CI/CD.
- Always ask who it's for: an ops dashboard needs fresh data; a monthly or quarterly executive report doesn't.

### Architecture decision records
- An ADR records one decision: the problem, the options, what you chose, and the risks you're taking on.
- No system is perfect. You always compromise, on cost, on time and in places you don't expect. ADRs record why the system is the way it is: a diary for the architect and the team.
- They also guide AI coding agents: a project's `CLAUDE.md` can point to its ADRs so an agent changes the right things. Record the general approach, such as batch or streaming, or Kubernetes over a managed service, not every detail.
- More on AI in data architecture in week 4, if there's time.

### Workshop
Fork the repo, find your launch customer, measure the delay per lane, sketch your architecture, and write ADR 001. There's no single right answer, only a defensible one, and a wrong one teaches you more. Talk to each other about why you'd go one way or the other. Send me your fork in Teams and I'll add comments. If you haven't finished session 2, use the time for that. The steps are in [workshop.md](workshop.md).

## Questions from the room
- **Did everyone finish sessions 1 and 2?** Not everyone. Use today's workshop time to catch up.
- **Is the launch customer per group? Can someone move from the four-person customer to a smaller one?** No need. Launch customers are individual, not group work. It doesn't matter how many people share one; you each present your own design at the board. You can talk to each other.
