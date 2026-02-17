

|  |
| :---- |

**OPENCLAW MASTERY**

**Anthropic Prompt Caching**

The Complete Setup Guide

|  |
| :---: |

Cut your Anthropic API costs dramatically

with intelligent prompt caching in OpenClaw

**SPRINT Program  |  ScaleUP Media**

docs.openclaw.ai/providers/anthropic

# **What is Prompt Caching?**

Prompt caching is a powerful cost-saving feature from Anthropic that allows your OpenClaw instance to reuse parts of previous prompts instead of reprocessing them from scratch every time. When you send repeated or similar prompts to Claude, the cached portions are served at a significantly reduced cost.

This is especially valuable when you're running agents with large system prompts, tool definitions, or context documents that stay consistent across multiple interactions. Instead of paying full price every time, you pay a fraction for the cached content.

| Why This Matters for Your Wallet Anthropic charges reduced rates for cached prompt tokens. With proper caching configured, you can see 50-90% cost reductions on repetitive API calls. If you're running agents 24/7, this adds up fast. |
| :---- |

# **Prerequisites**

Before configuring prompt caching, make sure you have the following in place:

* OpenClaw installed and running

* An Anthropic API key (not a setup-token / subscription)

* Your API key configured in OpenClaw via onboarding

* Access to your OpenClaw config file

| API Key Required Prompt caching is API-only. If you are using Claude subscription auth via a setup-token, cache settings will NOT work. You must use an Anthropic API key for caching to take effect. |
| :---- |

# **Authentication Setup**

OpenClaw supports two ways to authenticate with Anthropic. Here's a quick comparison to help you pick the right one:

| Feature | API Key | Setup-Token (Subscription) |
| :---- | :---- | :---- |
| Best For | Standard API access & billing | Using your Claude subscription |
| Prompt Caching | YES \- Full support | NO \- Not supported |
| Billing | Usage-based (pay per token) | Included in subscription |
| Setup Command | openclaw onboard | claude setup-token |

## **Setting Up Your API Key**

| 1 | Run the Onboarding Wizard |
| :---: | :---- |

Open your terminal and run the OpenClaw onboarding command. Select the Anthropic API key option when prompted:

| openclaw onboard \# Choose: Anthropic API key \# Or run non-interactively: openclaw onboard \--anthropic-api-key "$ANTHROPIC\_API\_KEY" |
| :---- |

| 2 | Verify Your Config |
| :---: | :---- |

After onboarding, your config should look like this. Open your OpenClaw config file and confirm the Anthropic API key is set:

| {   env: { ANTHROPIC\_API\_KEY: "sk-ant-..." },   agents: {     defaults: {       model: { primary: "anthropic/claude-opus-4-6" }     }   }, } |
| :---- |

# **Configuring Prompt Caching**

Now for the good stuff. OpenClaw gives you control over how long cached prompts are retained. This is configured using the cacheRetention parameter in your model config.

| 3 | Understand Cache Retention Options |
| :---: | :---- |

There are three cache retention levels available:

| Value | Cache Duration | Description |
| :---- | :---- | :---- |
| none | No caching | Disables prompt caching entirely |
| short | 5 minutes | Default when using an API key |
| long | 1 hour | Extended cache (requires beta flag) |

| Default Behavior When using Anthropic API Key authentication, OpenClaw automatically applies cacheRetention: "short" (5-minute cache) for all Anthropic models. You only need to change this if you want to disable caching or extend it to 1 hour. |
| :---- |

| 4 | Add Cache Retention to Your Config |
| :---: | :---- |

To set your preferred cache retention, add the cacheRetention parameter to your model config. Here's the recommended setup using the "long" (1-hour) cache for maximum savings:

| {   agents: {     defaults: {       models: {         "anthropic/claude-opus-4-6": {           params: { cacheRetention: "long" },         },       },     },   }, } |
| :---- |

If you want to apply caching to multiple models, repeat the pattern for each:

| {   agents: {     defaults: {       models: {         "anthropic/claude-opus-4-6": {           params: { cacheRetention: "long" },         },         "anthropic/claude-sonnet-4-5-20250929": {           params: { cacheRetention: "short" },         },       },     },   }, } |
| :---- |

| 5 | Understand the Beta Flag |
| :---: | :---- |

OpenClaw automatically includes the extended-cache-ttl-2025-04-11 beta flag in Anthropic API requests. This is what enables the "long" (1-hour) cache option.

If you have custom provider headers configured in your gateway settings, make sure you keep this beta flag intact. Removing it will break the "long" cache option.

# **Migrating from Legacy Settings**

If you've been using an older version of OpenClaw, you might have the legacy cacheControlTtl parameter in your config. Here's how the old values map to the new ones:

| Legacy Parameter | New Parameter | Cache Duration |
| :---- | :---- | :---- |
| cacheControlTtl: "5m" | cacheRetention: "short" | 5 minutes |
| cacheControlTtl: "1h" | cacheRetention: "long" | 1 hour |

| Action Required The legacy cacheControlTtl parameter still works but is deprecated. Update your configs to use cacheRetention to ensure compatibility with future OpenClaw releases. |
| :---- |

# **Troubleshooting**

**401 Errors / Token Suddenly Invalid**

* Claude subscription auth can expire or be revoked

* Re-run: claude setup-token and paste it into the gateway host

* If the Claude CLI login lives on a different machine, use: openclaw models auth paste-token \--provider anthropic

**No API Key Found for Provider "anthropic"**

* Auth is per agent. New agents don't inherit the main agent's keys

* Re-run onboarding for that agent, or paste a setup-token / API key on the gateway host

* Verify with: openclaw models status

**No Credentials Found for Profile**

* Run: openclaw models status to see which auth profile is active

* Re-run onboarding, or paste credentials for that profile

**No Available Auth Profile (All in Cooldown)**

* Check: openclaw models status \--json for auth.unusableProfiles

* Add another Anthropic profile or wait for cooldown to resolve

# **Quick Reference Card**

Keep this handy. Everything you need on one page.

**Essential Commands**

| \# Onboard with API key openclaw onboard \--anthropic-api-key "$ANTHROPIC\_API\_KEY" \# Check auth status openclaw models status \# Generate setup-token (subscription only) claude setup-token \# Paste token on gateway host openclaw models auth paste-token \--provider anthropic |
| :---- |

**Recommended Config (Maximum Savings)**

| {   env: { ANTHROPIC\_API\_KEY: "sk-ant-..." },   agents: {     defaults: {       model: { primary: "anthropic/claude-opus-4-6" },       models: {         "anthropic/claude-opus-4-6": {           params: { cacheRetention: "long" },         },       },     },   }, } |
| :---- |

**Cache Retention Cheat Sheet**

| Setting | Duration | When to Use |
| :---- | :---- | :---- |
| none | No cache | Testing / debugging |
| short | 5 min | Default \- good for most use cases |
| long | 1 hour | High-volume agents, max savings |

| Need Help? Have Questions? Drop your questions in the SPRINT community. We're here to help you optimize. |
| :---: |

