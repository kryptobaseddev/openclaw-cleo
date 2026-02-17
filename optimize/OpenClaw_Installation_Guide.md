  
**OpenClaw**

The Complete Installation & Setup Guide

*From zero to running — on your local machine or any VPS*

**openclaw.ai**

|  |
| :---- |

# **What Is OpenClaw?**

OpenClaw is an open-source AI automation framework that lets you build, orchestrate, and deploy autonomous AI agents and workflows. Think of it as the operating system for your AI automations — it handles model routing, task orchestration, tool integrations, and cost optimization so you can focus on building the actual business logic.

Whether you’re a developer building SaaS products, a solopreneur automating your business, or a “vibe coder” looking to monetize your skills, OpenClaw gives you the infrastructure to run AI agents at scale without burning through your API budget.

## **Why OpenClaw?**

| Cost Optimization | Strategic model routing can reduce your AI costs by up to 97%. Route simple tasks to lightweight models and reserve the heavy hitters for complex work. |
| :---- | :---- |
| **Agent Orchestration** | Build multi-step AI workflows that chain together tools, APIs, and models into reliable automated pipelines. |
| **Local-First** | Run everything on your own machine or VPS. Your data stays yours, your costs stay predictable, and you’re not locked into any vendor. |
| **Open Source** | Full transparency, community-driven development, and the freedom to customize everything to your specific use case. |

|  |
| :---- |

# **Prerequisites**

Before you install OpenClaw, make sure your system meets these minimum requirements:

* **Operating System:** macOS 12+, Ubuntu 20.04+ / Debian 11+, or any modern Linux distro. Windows users should use WSL2.

* **Node.js:** Version 18 or higher (recommended: v20 LTS)

* **Git:** Any recent version for cloning repos and version control

* **RAM:** Minimum 4GB (8GB+ recommended for running local models alongside OpenClaw)

* **Disk Space:** At least 2GB free for OpenClaw and dependencies

* **API Keys:** You’ll need at least one AI provider API key (Anthropic, OpenAI, etc.) to power your agents

| 💡 Tip: Check Your Node Version Run “node \--version” in your terminal. If you don’t have Node.js or it’s below v18, visit nodejs.org to grab the latest LTS release. |
| :---- |

|  |
| :---- |

# **Installation**

## **Step 1: Run the One-Line Installer**

OpenClaw provides a single command that handles the entire installation. Open your terminal and run:

curl \-fsSL https://openclaw.ai/install.sh | bash

This script is hosted at **https://openclaw.ai/** and it will automatically detect your operating system, download the correct binary, install dependencies, and add OpenClaw to your system PATH.

### **What the installer does:**

* Detects your OS and architecture (Intel/ARM, Linux/macOS)

* Downloads the latest stable OpenClaw release

* Installs required dependencies

* Adds the openclaw command to your PATH

* Creates the default config directory at \~/.openclaw/

| ⚠️ Security Note Always review install scripts before piping them to bash. You can inspect the script first by visiting https://openclaw.ai/install.sh in your browser, or by running: curl \-fsSL https://openclaw.ai/install.sh | less |
| :---- |

## **Step 2: Verify the Installation**

Once the installer finishes, verify everything is working:

openclaw \--version

You should see the version number printed to your terminal. If you get a “command not found” error, try restarting your terminal or running “source \~/.bashrc” (or “source \~/.zshrc” for zsh users).

## **Step 3: Initialize Your Project**

Navigate to your project directory (or create a new one) and initialize OpenClaw, your agent can do this for you as well:

mkdir my-openclaw-project  
cd my-openclaw-project  
openclaw onboard

This creates a configuration file and the basic project structure you’ll need to start building agents and workflows.

|  |
| :---- |

# **Basic Configuration**

After initialization, you’ll need to configure a few essential settings to get OpenClaw talking to your AI providers.

## **Setting Up API Keys**

OpenClaw supports multiple AI providers. Add your API keys using the built-in config command:

\# Add your Anthropic API key  
openclaw config set ANTHROPIC\_API\_KEY sk-ant-your-key-here

\# Add OpenAI (optional, for multi-model routing)  
openclaw config set OPENAI\_API\_KEY sk-your-key-here

Alternatively, you can set these as environment variables in your shell profile or in a .env file in your project root.

## **Configuring Model Routing**

One of OpenClaw’s most powerful features is intelligent model routing. This is how you can achieve massive cost savings — by sending simple tasks to cheaper, faster models and only using premium models when the task demands it. Open your project’s openclaw.config file and set up your tiers:

\# openclaw.config (example routing setup)

routing:  
  tier\_1:  \# Routine tasks (classification, formatting)  
    model: claude-haiku-4-5  
    max\_tokens: 1000

  tier\_2:  \# Complex execution (code gen, analysis)  
    model: claude-sonnet-4-5  
    max\_tokens: 4000

  tier\_3:  \# Strategic decisions (planning, architecture)  
    model: claude-opus-4-6  
    max\_tokens: 8000

| 💡 Pro Tip: The Three-Tier Strategy This three-tier approach is the foundation of how top OpenClaw users achieve 90%+ cost reductions. Most tasks in a typical automation workflow are Tier 1 (simple classification, data formatting, quick lookups). Only a small fraction need the full power of a frontier model. |
| :---- |

|  |
| :---- |

# **Deploying on a VPS**

While running OpenClaw locally is great for development and testing, you’ll want a VPS (Virtual Private Server) for anything running 24/7 in production. A VPS gives you always-on uptime, consistent performance, and the ability to run agents and automations unattended.

## **Recommended VPS Providers**

| Provider | Starting Price | Best For | Notes |
| :---- | :---- | :---- | :---- |
| **DigitalOcean** | $6/mo | Beginners | Simple UI, great docs |
| **Hetzner** | €4.50/mo | Cost efficiency | Best price-to-performance |
| **Linode (Akamai)** | $5/mo | Reliability | Solid network, good support |
| **Vultr** | $6/mo | Global reach | 30+ data center locations |
| **AWS Lightsail** | $5/mo | AWS ecosystem | Easy on-ramp to full AWS |

## **VPS Setup Steps**

Once you’ve provisioned your VPS (Ubuntu 22.04+ recommended), SSH in and follow these steps:

1. **Update your system and install Node.js:**

sudo apt update && sudo apt upgrade \-y  
curl \-fsSL https://deb.nodesource.com/setup\_20.x | sudo \-E bash \-  
sudo apt install \-y nodejs git

2. **Install OpenClaw with the same one-liner:**

curl \-fsSL https://openclaw.ai/install.sh | bash

3. **Initialize your project:**

openclaw onboard

4. **Use a process manager to keep OpenClaw running:**

\# Install PM2 for process management  
sudo npm install \-g pm2

\# Start your OpenClaw agent  
pm2 start openclaw \-- run agent.yaml

\# Ensure it restarts on reboot  
pm2 startup && pm2 save

| 💡 VPS Sizing Recommendation For most OpenClaw workloads, a 2 vCPU / 4GB RAM instance is plenty. OpenClaw itself is lightweight since the heavy AI processing happens on the provider’s side. You’re mainly paying for uptime and network reliability. |
| :---- |

|  |
| :---- |

# **Verifying Your Setup**

Run through this quick checklist to make sure everything is configured correctly:

1. **Check OpenClaw version:** openclaw \--version

2. **Verify API key is set:** openclaw config get ANTHROPIC\_API\_KEY

3. **Run a test prompt:** openclaw run \--test "Hello, are you working?"

4. **Check system health:** openclaw doctor

If all four commands return without errors, you’re good to go. OpenClaw is installed, configured, and ready to build with.

|  |
| :---- |

# **Common Troubleshooting**

* **“command not found: openclaw”** — Restart your terminal session, or manually add the install directory to your PATH. Run “source \~/.bashrc” or “source \~/.zshrc” depending on your shell.

* **“Permission denied” during install** — Don’t run the installer with sudo. If you hit permissions issues, check that your user owns the target directory: “sudo chown \-R $USER /usr/local/lib/openclaw”

* **API key errors** — Double-check your key with “openclaw config get ANTHROPIC\_API\_KEY”. Make sure you’re using the full key string and that your API account has available credits.

* **Connection timeouts on VPS** — Ensure your VPS firewall allows outbound HTTPS (port 443). On Ubuntu: “sudo ufw allow out 443”

* **High memory usage** — Check which models you’re routing to. If you’re running local models alongside OpenClaw, you may need to upgrade your VPS tier.

|  |
| :---- |

# **Next Steps**

Now that OpenClaw is installed and running, here’s where to go from here:

* **Explore the docs:** Visit openclaw.ai for full documentation, tutorials, and example workflows.

* **Build your first agent:** Start with a simple single-task agent to get familiar with the YAML workflow format.

* **Set up model routing:** Configure your three-tier model strategy to start optimizing costs from day one.

* **Join the community:** Connect with other OpenClaw users to share configs, workflows, and optimization tips.

* **Automate something real:** Pick a repetitive task in your business and build an agent to handle it. That’s where the magic happens.

| Ready to Build? Get started in 30 seconds: curl \-fsSL https://openclaw.ai/install.sh | bash Visit openclaw.ai for full documentation and community resources. |
| :---: |

