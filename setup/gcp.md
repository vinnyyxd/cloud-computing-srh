# Google Cloud setup

You need one Google Cloud project for the whole module, on your own account with the free trial.

## The free trial

1. Go to cloud.google.com and click **Get started for free**.
2. Sign in with a personal Google account.
3. Choose your country and the individual account type, then add a card. It verifies your identity; nothing is charged unless you upgrade.
4. You get $300 (about €269) of credit for 90 days.
5. Search **Budgets and alerts**, create a budget of €50, keep the 50/90/100% alerts.
6. Create a project called `cc-<your-name>`.

Budgets only send emails; they don't stop anything. Stop Dataflow jobs and scale clusters down at the end of every session.

## Cloud Shell tips

Most workshops run in Cloud Shell. It keeps everything in your home folder (`~`) between sessions, and it has Docker, `kubectl` and `gcloud` already. Terraform you install once, into your home folder (tip 3). Do these once:

1. **Turn off ephemeral mode.** In the Cloud Shell toolbar, open the **⋮** menu and check **Ephemeral mode** is off. If it's on, your home folder is wiped when the session ends, and you lose the repo, your `terraform.tfvars` and your Terraform state.
2. **Share Terraform's downloads between sessions.** Each session's `starter/` folder is its own Terraform project, so `terraform init` downloads the Google provider again in each one. Run this once and it downloads only once:

   ```bash
   mkdir -p ~/.terraform.d/plugin-cache && echo 'plugin_cache_dir = "$HOME/.terraform.d/plugin-cache"' > ~/.terraformrc
   ```

3. **Install Terraform in your home folder.** Cloud Shell no longer includes it: its `terraform` only prints installation instructions, and commands like `terraform apply` then look as if they worked but do nothing. Anything installed outside your home folder, with `apt` for example, is gone the next time Cloud Shell starts, so put it in `~/bin` instead. This downloads Terraform from HashiCorp, checks the download against HashiCorp's published checksum, and puts `~/bin` first on your path:

   ```bash
   cd ~ && V=1.9.8
   curl -sSfLO https://releases.hashicorp.com/terraform/$V/terraform_${V}_linux_amd64.zip
   curl -sSfL https://releases.hashicorp.com/terraform/$V/terraform_${V}_SHA256SUMS | grep linux_amd64.zip | sha256sum -c -
   mkdir -p ~/bin && unzip -o terraform_${V}_linux_amd64.zip terraform -d ~/bin && rm terraform_${V}_linux_amd64.zip
   grep -qs 'HOME/bin:' ~/.bashrc || echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc; source ~/.bashrc
   terraform version
   ```

   The check should print `OK`, and `terraform version` should print `Terraform v1.9.8`. It may add that a newer version exists: ignore that, since 1.9.8 is the version the workshops are tested with. Open a new Cloud Shell tab and run `terraform version` there too. If it prints installation instructions instead of a version, check that `grep 'HOME/bin' ~/.bashrc` shows the `export PATH` line. Running these steps again is safe: they add that line only once.

If your repo folder has disappeared, run `git clone` again. If `terraform apply` then says a bucket or table **already exists**, Terraform has lost its state: tell me, and we'll bring your resources back under Terraform with `terraform import`.
