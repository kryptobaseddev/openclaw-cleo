# Mission Control

**MISSION CONTROL** 

![][image1]

**Overview**

OpenClaw Mission Control is your local AI operations dashboard.

It runs at:  
[http://localhost:3001/](http://localhost:3001/)  
Mission Control does **not** replace the main OpenClaw Web UI.  
It is an orchestration layer built for:

* Managing multiple projects  
* Structuring execution  
* Running agents intentionally  
* Scheduling automation  
* Tracking outputs and logs  
* Operating like a system, not chaos

If OpenClaw is the engine, Mission Control is the command center.

**1\. Projects**

Projects are the foundation of Mission Control.  
Every task, agent, schedule, and output is tied to a project.

**Creating a Project**

When creating a new project, define:

* Project name  
* Description  
* Project root directory  
* Output directory  
* Assigned agent(s)  
* Optional Git reference

Keep each project isolated.  
This prevents cross contamination between builds.

**Project Dashboard**

Each project includes:

* Active tasks  
* Assigned agents  
* Scheduled jobs  
* Recent runs  
* Output artifacts  
* Activity timeline

Use this page as your execution overview.

**2\. Tasks**

Tasks are structured work units inside a project.  
There are three types:

* Plan  
* Build  
* Ops

**Creating a Task**

Each task includes:

* Title  
* Description  
* Type  
* Priority  
* Status  
* Assigned agent  
* Expected deliverables

Tasks move across statuses:  
Backlog → Planned → In Progress → Blocked → Done  
Use this to manage real execution flow.

**Running a Task**

Click “Run Task” to trigger execution.  
What happens:

1. Mission Control calls the OpenClaw adapter  
2. The correct agent is executed  
3. Logs stream live  
4. Outputs are written to the project output directory  
5. Run history is saved

You can monitor:

* Status  
* Start time  
* End time  
* Logs  
* Produced artifacts

This is real execution, not simulation.

**3\. Agents and Sub Agents**

Agents are automatically discovered from:  
\~/.openclaw/openclaw.json  
You can:

* View available agents  
* Assign agents to projects  
* Define a primary agent  
* Use sub agents for specialization

Think of this as your AI team structure.  
Each project can have a different loadout.

**4\. Scheduler and Cron Jobs**

Mission Control supports recurring automation.  
**Creating a Scheduled Job**

You define:

* Project  
* Job type  
* Cron expression  
* Enabled or disabled state

You can:

* Run immediately  
* Enable or disable  
* View next run time  
* Review run history

The system prevents overlapping runs by default.  
Use scheduler jobs for:

* Reporting  
* Monitoring  
* Outreach  
* Maintenance tasks  
* Recurring build checks

**5\. Web Chat (Project Context)**

Each project includes a contextual chat interface.  
This is not generic prompting.  
This is project aware AI.

**How Chat Works**

1. Select project  
2. Select agent  
3. Optionally attach:  
   * A task  
   * Specific files  
4. Send message  
5. Response streams live

You can:

* Save chat output to task notes  
* Create a task from chat  
* Export the session to markdown  
* Store full chat history

All chat sessions are saved per project.

**6\. Files and Outputs**

Each project includes a file browser for its output directory.  
You can:

* Browse directory tree  
* Search filenames  
* Preview small text files  
* Copy file paths  
* Open folder in your OS  
* Link files to tasks

Artifacts from runs are tracked and organized.  
No more digging through random folders.

**7\. Dashboard Overview**

The global Mission Control dashboard shows:

* Active tasks across projects  
* Running executions  
* Upcoming scheduled jobs  
* Recent completions  
* Blocked tasks

Use this page to understand system health.

**8\. Execution Architecture**

When a task runs:

1. UI triggers backend API  
2. Backend validates project paths  
3. OpenClaw CLI is executed via allowlisted command  
4. Logs stream via WebSocket  
5. Run is persisted in database  
6. Output artifacts are indexed

Everything is local.  
Everything is tracked.

**9\. Security Model**

Mission Control:

* Binds to 127.0.0.1 by default  
* Validates project root paths  
* Prevents arbitrary command execution  
* Does not store secrets in plain text  
* Uses environment variable references where needed

Execution is controlled and bounded.

**10\. Operational Best Practices**

To get the most out of Mission Control:

* Keep projects isolated  
* Define clear task deliverables  
* Use scheduler for recurring work  
* Assign agents intentionally  
* Review logs after major runs  
* Keep output directories clean and structured

Treat this as infrastructure, not a toy dashboard.

**11\. What Mission Control Enables**

You now have:

* Structured multi project management  
* Agent orchestration  
* Real execution logging  
* Recurring automation  
* Contextual AI chat  
* Artifact traceability  
* System level visibility

This is how you move from prompting to operating.

# Option A) From My Agent

\# OpenClaw Mission Control: Build It Yourself  
\#\# Step-by-Step Prompts for The Sprint Community

\---

\#\# BEFORE YOU START

\*\*Prerequisites:\*\*  
\- \[ \] Node.js 18+  
\- \[ \] Mac or Linux (Windows via WSL)  
\- \[ \] Code editor (VS Code recommended)  
\- \[ \] Git (optional, but helpful)  
\- \[ \] 30-40 hours of time over 3-4 weeks

\*\*Setup (10 minutes):\*\*  
1\. Clone or download the codebase from: \[GitHub Link\]  
2\. Run \`cd openclaw-control-center\`  
3\. Follow SETUP.md to get the app running locally

\*\*Test your setup:\*\*  
\`\`\`bash  
\# Terminal 1 \- Backend  
cd backend  
npm install  
npx prisma migrate dev  
npm run dev

\# Terminal 2 \- Frontend  
cd frontend  
npm install  
npm run dev

\# Should see:  
\# Backend: http://localhost:3000  
\# Frontend: http://localhost:3001  
\`\`\`

\---

\#\# PHASE 3: OpenClaw Adapter  
\*\*Time: 3-4 days | Difficulty: Medium | Core Skill: Child processes & streaming\*\*

\#\#\# What You'll Build  
A service that:  
\- Reads your OpenClaw config file  
\- Discovers available agents  
\- Executes tasks via child\_process  
\- Streams output to the UI in real-time  
\- Validates paths for security

\#\#\# Prompt 1: Create the OpenClaw Adapter

\*\*Your task:\*\*  
Create \`/backend/src/lib/openclaw.ts\` with an \`OpenClawAdapter\` class.

\*\*Requirements:\*\*  
\- Read and parse \`\~/.openclaw/openclaw.json\`  
\- Extract agent list from config  
\- Implement \`getAgents()\` function  
\- Implement \`validatePath()\` function (security\!)  
\- Export as singleton

\*\*Hint:\*\*  
\- Use Node.js \`fs\` module to read files  
\- Use \`path.resolve()\` for path validation  
\- Use \`os.homedir()\` to expand \`\~\` in paths

\*\*Verification:\*\*  
\`\`\`bash  
\# In backend directory  
npm run type-check  \# Should have no errors  
\`\`\`

\*\*Code template (fill in the blanks):\*\*  
\`\`\`typescript  
// /backend/src/lib/openclaw.ts  
import fs from 'fs';  
import path from 'path';  
import os from 'os';

export class OpenClawAdapter {  
  private configPath: string;  
  private config: any \= null;

  constructor(configPath: string \= '\~/.openclaw/openclaw.json') {  
    // TODO: Expand the path (\~ → home directory)  
    this.configPath \= /\* YOUR CODE \*/;  
  }

  private expandPath(filePath: string): string {  
    // TODO: Replace \~ with home directory  
    if (filePath.startsWith('\~')) {  
      return path.join(/\* YOUR CODE \*/);  
    }  
    return filePath;  
  }

  async loadConfig(): Promise\<any\> {  
    // TODO: Read and parse the JSON file  
    const content \= fs.readFileSync(/\* YOUR CODE \*/);  
    this.config \= JSON.parse(content);  
    return this.config;  
  }

  async getAgents(): Promise\<any\[\]\> {  
    if (\!this.config) {  
      await this.loadConfig();  
    }  
    // TODO: Return the agents array from config  
    return /\* YOUR CODE \*/;  
  }

  validatePath(filePath: string, allowlist: string\[\]): boolean {  
    // TODO: Check if filePath is within any allowlist item  
    const resolved \= path.resolve(filePath);  
      
    for (const allowed of allowlist) {  
      const allowedResolved \= path.resolve(this.expandPath(allowed));  
      // TODO: Check if resolved is within allowedResolved  
      if (/\* YOUR CODE \*/) {  
        return true;  
      }  
    }  
      
    return false;  
  }  
}

export const openclawAdapter \= new OpenClawAdapter();  
\`\`\`

\---

\#\#\# Prompt 2: Add Agent Discovery API Endpoint

\*\*Your task:\*\*  
Add a new endpoint to \`/backend/src/server.ts\` that discovers and stores agents.

\*\*Requirements:\*\*  
\- Endpoint: \`POST /api/settings/discover-agents\`  
\- Read config using OpenClawAdapter  
\- Store/update agents in database (Prisma)  
\- Return list of discovered agents

\*\*Hint:\*\*  
\- Use \`prisma.agent.upsert()\` to create or update agents  
\- Handle errors gracefully (config file not found, parse errors)

\*\*Code template:\*\*  
\`\`\`typescript  
// Add to /backend/src/server.ts

app.post('/api/settings/discover-agents', async (req, res) \=\> {  
  try {  
    // TODO: Call openclawAdapter.getAgents()  
    const agents \= /\* YOUR CODE \*/;  
      
    // TODO: For each agent, upsert it into the database  
    for (const agent of agents) {  
      await prisma.agent.upsert({  
        where: { id: agent.id },  
        update: {  
          name: agent.name,  
          model: agent.model,  
          // TODO: Any other fields  
        },  
        create: {  
          id: agent.id,  
          name: agent.name || agent.id,  
          model: agent.model || 'claude-haiku',  
          capabilities: JSON.stringify(agent.capabilities || \[\]),  
          // TODO: Any other fields  
        }  
      });  
    }  
      
    // TODO: Return the updated agents list  
    const allAgents \= /\* YOUR CODE \*/;  
    res.json(allAgents);  
  } catch (error) {  
    console.error('Agent discovery failed:', error);  
    res.status(500).json({ error: 'Failed to discover agents' });  
  }  
});  
\`\`\`

\*\*Test it:\*\*  
\`\`\`bash  
curl \-X POST http://localhost:3000/api/settings/discover-agents

\# Should return: \[{ id, name, model, capabilities, ... }\]  
\`\`\`

\---

\#\#\# Prompt 3: Implement Task Execution

\*\*Your task:\*\*  
Create \`/backend/src/services/taskExecutor.ts\` that runs a task and streams output.

\*\*Requirements:\*\*  
\- Accept task ID, command, and working directory  
\- Create a TaskRun record in DB  
\- Spawn child\_process with the command  
\- Capture stdout/stderr  
\- Broadcast output via WebSocket  
\- Save final status and logs to DB

\*\*Hint:\*\*  
\- Import \`spawn\` from \`child\_process\`  
\- Return a Promise that resolves when process exits  
\- Use WebSocket to broadcast to connected clients

\*\*Code template:\*\*  
\`\`\`typescript  
// /backend/src/services/taskExecutor.ts  
import { spawn } from 'child\_process';  
import { PrismaClient } from '@prisma/client';  
import { WebSocketServer } from 'ws';

export class TaskExecutor {  
  constructor(  
    private prisma: PrismaClient,  
    private wss: WebSocketServer  
  ) {}

  async executeTask(  
    taskId: string,  
    command: string,  
    workingDir: string  
  ): Promise\<string\> {  
    // TODO: Create TaskRun record  
    const taskRun \= await this.prisma.taskRun.create({  
      data: {  
        taskId,  
        status: 'Running',  
        startTime: new Date(),  
        logs: '',  
      },  
    });

    const streamId \= taskRun.id;

    try {  
      // TODO: Spawn the process  
      const process \= spawn(/\* YOUR CODE \*/, {  
        cwd: workingDir,  
        shell: true,  
      });

      let logs \= '';

      // TODO: Handle stdout  
      process.stdout.on('data', (data) \=\> {  
        const chunk \= data.toString();  
        logs \+= chunk;  
          
        // TODO: Broadcast to WebSocket subscribers  
        /\* YOUR CODE \*/;  
      });

      // TODO: Handle stderr  
      process.stderr.on('data', (data) \=\> {  
        /\* YOUR CODE \*/;  
      });

      // TODO: Wait for process to finish  
      const exitCode \= await new Promise\<number\>((resolve) \=\> {  
        process.on('exit', (code) \=\> {  
          resolve(code || 0);  
        });  
      });

      // TODO: Update TaskRun with final status  
      await this.prisma.taskRun.update({  
        where: { id: taskRun.id },  
        data: {  
          status: exitCode \=== 0 ? 'Completed' : 'Failed',  
          endTime: new Date(),  
          exitCode,  
          logs,  
        },  
      });

      return streamId;  
    } catch (error) {  
      // TODO: Handle errors  
      await this.prisma.taskRun.update({  
        where: { id: taskRun.id },  
        data: {  
          status: 'Failed',  
          endTime: new Date(),  
          logs: String(error),  
        },  
      });  
      throw error;  
    }  
  }

  private broadcastTaskStream(streamId: string, event: string, data: string) {  
    const message \= JSON.stringify({  
      type: 'task-stream',  
      streamId,  
      event,  
      data,  
      timestamp: new Date().toISOString(),  
    });

    // TODO: Send to all WebSocket clients  
    this.wss.clients.forEach((client) \=\> {  
      // TODO: Check if client is subscribed to this stream  
      if (/\* YOUR CODE \*/ && client.readyState \=== 1\) {  
        client.send(message);  
      }  
    });  
  }  
}  
\`\`\`

\*\*Test it:\*\*  
\`\`\`bash  
\# Create a task first, then:  
curl \-X POST http://localhost:3000/api/tasks/:id/run

\# Should return: { taskRunId: "...", status: "Running" }  
\`\`\`

\---

\#\#\# Prompt 4: Wire Task Execution to API

\*\*Your task:\*\*  
Add \`/api/tasks/:id/run\` endpoint that calls TaskExecutor.

\*\*Requirements:\*\*  
\- Find the task by ID  
\- Validate it exists  
\- Call taskExecutor.executeTask()  
\- Return the stream ID  
\- Handle errors

\*\*Code template:\*\*  
\`\`\`typescript  
app.post('/api/tasks/:id/run', async (req, res) \=\> {  
  try {  
    const { id } \= req.params;  
      
    // TODO: Find the task  
    const task \= /\* YOUR CODE \*/;  
      
    if (\!task) {  
      return res.status(404).json({ error: 'Task not found' });  
    }

    // TODO: Get project details  
    const project \= /\* YOUR CODE \*/;  
      
    // TODO: Get settings (for allowlist)  
    const settings \= /\* YOUR CODE \*/;  
      
    // TODO: Create TaskExecutor instance  
    const taskExecutor \= new TaskExecutor(prisma, wss);  
      
    // TODO: Execute task  
    const streamId \= await taskExecutor.executeTask(  
      task.id,  
      'echo "Task executed"', // Stub command for now  
      project.projectRootPath  
    );

    res.status(202).json({ taskRunId: streamId, status: 'Running' });  
  } catch (error) {  
    res.status(500).json({ error: String(error) });  
  }  
});  
\`\`\`

\---

\#\#\# Phase 3 Checkpoint  
\*\*Verify you can:\*\*  
\- \[ \] Discover agents from OpenClaw config  
\- \[ \] Create a task in the UI  
\- \[ \] Click "Run Task" and see it execute  
\- \[ \] Check the database: TaskRun record created  
\- \[ \] See logs streaming via WebSocket (in browser console)

\*\*If stuck:\*\*  
\- Check backend logs: \`npm run dev\` output  
\- Verify task command works: \`echo "test"\` in your shell  
\- Check WebSocket connection: Open browser DevTools → Network → WS

\---

\#\# PHASE 4: Scheduler System  
\*\*Time: 3-4 days | Difficulty: Medium | Core Skill: Cron scheduling\*\*

\#\#\# What You'll Build  
A scheduler that:  
\- Loads jobs from database on startup  
\- Registers jobs with node-cron  
\- Executes jobs on schedule  
\- Records execution history  
\- Updates UI via WebSocket

\#\#\# Prompt 5: Create Scheduler Service

\*\*Your task:\*\*  
Create \`/backend/src/services/scheduler.ts\` with a \`SchedulerService\` class.

\*\*Requirements:\*\*  
\- Constructor accepts Prisma and WebSocketServer  
\- \`initialize()\`: Load all enabled jobs from DB, register them  
\- \`scheduleJob()\`: Register a single job with node-cron  
\- \`executeJob()\`: Run a job immediately  
\- \`unscheduleJob()\`: Stop a scheduled job

\*\*Hint:\*\*  
\- Use \`import \* as cron from 'node-cron'\`  
\- Use \`cron.schedule(cronExpression, callback)\`  
\- Use \`cron.nextDate()\` to calculate next run time

\*\*Code template:\*\*  
\`\`\`typescript  
// /backend/src/services/scheduler.ts  
import \* as cron from 'node-cron';  
import { PrismaClient } from '@prisma/client';  
import { WebSocketServer } from 'ws';

export class SchedulerService {  
  private scheduledTasks: Map\<string, any\> \= new Map();

  constructor(  
    private prisma: PrismaClient,  
    private wss: WebSocketServer  
  ) {}

  async initialize() {  
    // TODO: Load all enabled jobs from DB  
    const jobs \= /\* YOUR CODE \*/;

    // TODO: For each job, call scheduleJob()  
    for (const job of jobs) {  
      /\* YOUR CODE \*/;  
    }

    console.log(\`Scheduler initialized with ${jobs.length} jobs\`);  
  }

  async scheduleJob(job: any) {  
    // TODO: Prevent duplicate schedules  
    if (this.scheduledTasks.has(job.id)) {  
      this.unscheduleJob(job.id);  
    }

    try {  
      // TODO: Create cron schedule  
      const task \= cron.schedule(job.cronExpression, async () \=\> {  
        await this.executeJob(job.id);  
      });

      this.scheduledTasks.set(job.id, task);

      // TODO: Calculate next run time  
      const nextRunAt \= /\* YOUR CODE \*/;  
        
      // TODO: Update job in DB with nextRunAt  
      await this.prisma.schedulerJob.update({  
        where: { id: job.id },  
        data: { nextRunAt: new Date(nextRunAt.toString()) },  
      });  
    } catch (error) {  
      console.error(\`Failed to schedule job ${job.id}:\`, error);  
    }  
  }

  async unscheduleJob(jobId: string) {  
    // TODO: Stop the cron task  
    const task \= this.scheduledTasks.get(jobId);  
    if (task) {  
      task.stop();  
      this.scheduledTasks.delete(jobId);  
    }  
  }

  async executeJob(jobId: string) {  
    // TODO: Find job in DB  
    const job \= /\* YOUR CODE \*/;  
      
    if (\!job) return;

    try {  
      // TODO: Create SchedulerJobRun record  
      const jobRun \= await this.prisma.schedulerJobRun.create({  
        data: {  
          jobId,  
          status: 'Running',  
          startTime: new Date(),  
        },  
      });

      // TODO: If job type is RunTask, execute the task  
      if (job.jobType \=== 'RunTask' && job.targetTaskId) {  
        // TODO: Call your TaskExecutor here  
        /\* YOUR CODE \*/;  
      }

      // TODO: Update job run to completed  
      await this.prisma.schedulerJobRun.update({  
        where: { id: jobRun.id },  
        data: {  
          status: 'Completed',  
          endTime: new Date(),  
          exitCode: 0,  
        },  
      });

      // TODO: Broadcast update via WebSocket  
      this.broadcastSchedulerUpdate(jobId, 'completed');  
    } catch (error) {  
      console.error(\`Job execution failed: ${jobId}\`, error);  
      // TODO: Handle error  
    }  
  }

  private broadcastSchedulerUpdate(jobId: string, status: string) {  
    const message \= JSON.stringify({  
      type: 'scheduler-update',  
      jobId,  
      status,  
      timestamp: new Date().toISOString(),  
    });

    // TODO: Send to all WebSocket clients  
    this.wss.clients.forEach((client) \=\> {  
      if (client.readyState \=== 1\) {  
        client.send(message);  
      }  
    });  
  }  
}  
\`\`\`

\---

\#\#\# Prompt 6: Wire Scheduler to Server

\*\*Your task:\*\*  
Update \`/backend/src/server.ts\` to:  
\- Instantiate SchedulerService on startup  
\- Add API endpoints for job management  
\- Call \`initialize()\` after server starts

\*\*Requirements:\*\*  
\- Add \`POST /api/scheduler\` (create job)  
\- Add \`GET /api/scheduler\` (list jobs)  
\- Add \`POST /api/scheduler/:id/run-now\` (execute immediately)  
\- Add \`PUT /api/scheduler/:id/enable\` and \`/disable\`

\*\*Code template (endpoints):\*\*  
\`\`\`typescript  
const schedulerService \= new SchedulerService(prisma, wss);

httpServer.listen(PORT, async () \=\> {  
  // TODO: Initialize scheduler after server starts  
  await schedulerService.initialize();  
    
  console.log(\`Server running on port ${PORT}\`);  
});

app.post('/api/scheduler', async (req, res) \=\> {  
  try {  
    const { projectId, name, jobType, cronExpression, timezone, enabled } \= req.body;

    // TODO: Validate inputs  
      
    // TODO: Create job in DB  
    const job \= /\* YOUR CODE \*/;

    // TODO: If enabled, schedule it  
    if (enabled) {  
      await schedulerService.scheduleJob(job);  
    }

    res.status(201).json(job);  
  } catch (error) {  
    res.status(500).json({ error: String(error) });  
  }  
});

app.post('/api/scheduler/:id/run-now', async (req, res) \=\> {  
  try {  
    const { id } \= req.params;  
      
    // TODO: Execute the job immediately  
    await schedulerService.executeJob(id);  
      
    res.json({ status: 'running' });  
  } catch (error) {  
    res.status(500).json({ error: String(error) });  
  }  
});

app.put('/api/scheduler/:id/enable', async (req, res) \=\> {  
  try {  
    const { id } \= req.params;  
      
    // TODO: Find job  
    const job \= /\* YOUR CODE \*/;  
      
    // TODO: Update enabled \= true  
    const updated \= /\* YOUR CODE \*/;  
      
    // TODO: Schedule it  
    await schedulerService.scheduleJob(updated);  
      
    res.json(updated);  
  } catch (error) {  
    res.status(500).json({ error: String(error) });  
  }  
});  
\`\`\`

\---

\#\#\# Phase 4 Checkpoint  
\*\*Verify you can:\*\*  
\- \[ \] Create a scheduler job (POST /api/scheduler)  
\- \[ \] List jobs (GET /api/scheduler)  
\- \[ \] Click "Run Now" and see it execute  
\- \[ \] Enable/disable a job  
\- \[ \] Check database: SchedulerJobRun created with correct status

\---

\#\# PHASE 5 & 6: Quick Build (Follow These Patterns)

\#\#\# Phase 5: Chat System (2-3 days)  
\*\*What to build:\*\*  
\- \`POST /api/projects/:id/chat\` \- Send message  
\- \`GET /api/projects/:id/chat\` \- Get history  
\- WebSocket handler for streaming responses

\*\*Key pattern:\*\*  
\`\`\`typescript  
// Save user message  
await prisma.chatMessage.create({  
  data: { chatSessionId, role: 'User', content: message }  
});

// Simulate agent response (later: integrate real agent)  
const response \= \`Response to: "${message}"\`;

// Save agent message  
await prisma.chatMessage.create({  
  data: { chatSessionId, role: 'Agent', content: response }  
});

// Broadcast  
wss.clients.forEach(client \=\> {  
  client.send(JSON.stringify({ type: 'chat-message', content: response }));  
});  
\`\`\`

\#\#\# Phase 6: Files System (2-3 days)  
\*\*What to build:\*\*  
\- \`GET /api/projects/:id/files\` \- List directory  
\- \`POST /api/files/open\` \- Open folder in OS

\*\*Key pattern:\*\*  
\`\`\`typescript  
import fs from 'fs';  
import path from 'path';

function buildFileTree(dirPath, depth \= 0\) {  
  const files \= fs.readdirSync(dirPath);  
  return files.map(file \=\> ({  
    name: file,  
    path: path.join(dirPath, file),  
    type: fs.statSync(path.join(dirPath, file)).isDirectory() ? 'dir' : 'file',  
    children: /\* recursively list subdirs \*/  
  }));  
}  
\`\`\`

\---

\#\# PHASE 7: UI Wiring (Done in Frontend)

\#\#\# Setup State Management

\*\*Install Zustand:\*\*  
\`\`\`bash  
cd frontend  
npm install zustand  
\`\`\`

\*\*Create store:\*\*  
\`\`\`typescript  
// /frontend/src/store/appStore.ts  
import { create } from 'zustand';

interface AppState {  
  projects: any\[\];  
  tasks: any\[\];  
  selectedProjectId: string | null;  
    
  setProjects: (projects: any\[\]) \=\> void;  
  setTasks: (tasks: any\[\]) \=\> void;  
}

export const useAppStore \= create\<AppState\>((set) \=\> ({  
  projects: \[\],  
  tasks: \[\],  
  selectedProjectId: null,  
    
  setProjects: (projects) \=\> set({ projects }),  
  setTasks: (tasks) \=\> set({ tasks }),  
}));  
\`\`\`

\#\#\# Update Dashboard Component

\*\*Replace "Coming Soon" with real data:\*\*  
\`\`\`typescript  
// /frontend/src/pages/Dashboard.tsx  
import { useEffect } from 'react';  
import { useAppStore } from '../store/appStore';

export default function Dashboard() {  
  const projects \= useAppStore(state \=\> state.projects);  
  const setProjects \= useAppStore(state \=\> state.setProjects);

  useEffect(() \=\> {  
    // Fetch projects  
    fetch('/api/projects')  
      .then(res \=\> res.json())  
      .then(data \=\> setProjects(data));  
  }, \[\]);

  return (  
    \<div className="p-8"\>  
      \<h1 className="text-4xl font-bold mb-8"\>Dashboard\</h1\>  
        
      {/\* Real data instead of hardcoded \*/}  
      \<div className="grid grid-cols-3 gap-6"\>  
        {projects.map(project \=\> (  
          \<div key={project.id} className="bg-gray-800 p-6 rounded-lg"\>  
            \<h3 className="text-xl font-semibold"\>{project.name}\</h3\>  
            \<p className="text-gray-400"\>{project.description}\</p\>  
          \</div\>  
        ))}  
      \</div\>  
    \</div\>  
  );  
}  
\`\`\`

\---

\#\# TROUBLESHOOTING GUIDE

\#\#\# "Port 3000 already in use"  
\`\`\`bash  
lsof \-ti:3000 | xargs kill \-9  
\`\`\`

\#\#\# "Cannot find module 'prisma'"  
\`\`\`bash  
npm install  
npx prisma generate  
\`\`\`

\#\#\# "Database locked"  
\`\`\`bash  
rm backend/prisma/data.db-\*  
npx prisma migrate dev \--skip-generate  
\`\`\`

\#\#\# "WebSocket connection refused"  
Check backend is running: \`npm run dev\` in backend folder

\#\#\# Task execution doesn't stream logs  
Check browser DevTools → Network → WS tab for WebSocket messages

\---

\#\# NEXT STEPS AFTER COMPLETING ALL PHASES

1\. \*\*Deploy to a VPS\*\* (DigitalOcean, Render, Fly.io)  
2\. \*\*Add authentication\*\* (if sharing with team)  
3\. \*\*Integrate real OpenClaw agents\*\* (sessions\_spawn)  
4\. \*\*Add notifications\*\* (email on task completion)  
5\. \*\*Build plugins\*\* (custom integrations)

\---

\#\# FINAL CHECKLIST

When you're done, you should be able to:  
\- \[ \] Create projects from the UI  
\- \[ \] Create tasks and drag them across a kanban board  
\- \[ \] Click "Run Task" and see logs stream in real-time  
\- \[ \] Create scheduler jobs and see them execute  
\- \[ \] Chat with agents and save conversations  
\- \[ \] Browse project output files  
\- \[ \] All data persists across app restarts  
\- \[ \] No "Coming Soon" text anywhere

If all boxes checked: \*\*You've built Mission Control\!\*\*

\---

\*\*Questions? Join The Sprint or office hours.\*\*

\*\*Ready to build?\*\*

# Option B) My Prompts

Phase 1: 

You are my senior full stack engineer and product designer.

New Project: OpenClaw Web UI Control Center (Local Mission Control)  
Goal: Build a polished, local hosted “mission control” dashboard that helps me manage all my OpenClaw projects, tasks, sub agents, automations, and output folders in one place.

Important context  
\- This is NOT replacing the existing OpenClaw Web UI. This is an optional second dashboard focused on operating multiple projects at once.  
\- I run many projects in parallel and I need strict separation by project.  
\- This must be hosted locally (LAN only by default). It can run on Mac or Linux, and optionally on a VPS later, but build for local first.  
\- It must integrate with my OpenClaw configuration and filesystem outputs. It should link to output folders and open files quickly.

Primary user  
\- Me (operator) and optionally a small internal team  
\- I need quick visibility, fast triage, and clear next actions across projects.

High level outcomes  
1\) One dashboard to view all projects and their status at a glance  
2\) Create and manage projects, tasks, and sub agents with clear workflows  
3\) Track active tasks, queued tasks, and completed tasks with logs and artifacts  
4\) Built in web chat that can talk to an OpenClaw agent in the context of a selected project  
5\) A cron and scheduler area for recurring jobs (view, create, edit, run now, enable/disable)  
6\) Strong file and output management: link to folders, browse artifacts, search, and open in OS file explorer  
7\) Clean UI, fast, reliable, with an operational feel (mission control)

Non goals  
\- Do not attempt to rebuild OpenClaw’s entire UI or add features that already exist there.  
\- Do not add cloud dependencies. Local first. Offline friendly.  
\- No heavy enterprise auth. Keep it simple and secure for local use.

Tech requirements (choose a modern but simple stack)  
\- Frontend: React \+ TypeScript \+ Tailwind  
\- Backend: Node.js (Express or Fastify) \+ TypeScript  
\- DB: SQLite (via Prisma or Drizzle). Local file stored under a project data directory.  
\- Real time: WebSocket for task status updates and chat streaming.  
\- Packaging: Docker Compose optional, but must also run via npm scripts locally.  
\- OS integration: Provide “Open Folder” and “Reveal in Finder” style actions (Mac) and equivalent for Linux. If direct opening is not possible from browser, implement a backend endpoint that triggers OS open via shell command with strong path validation.

Integration requirements  
\- OpenClaw config file lives at: \~/.openclaw/openclaw.json  
\- The Control Center must be able to read that config (read only by default).  
\- It should detect agents defined in config and show them as available “sub agents”.  
\- It should support a per project mapping to:  
  \- which agent(s) are used  
  \- working directory root  
  \- output folder root  
  \- environment variables or secrets references (do not store secrets in plain text)  
\- It must show running tasks and completed tasks, and point to their output artifacts on disk.

Core features (must build)  
A) Projects  
\- Create new project wizard  
  \- Name, description, tags  
  \- Project root directory path  
  \- Output directory path  
  \- Default agent or agent group (from openclaw.json)  
  \- Optional Git repo link (just metadata)  
  \- Operations cadence (daily, weekly) metadata  
\- Project detail page  
  \- Overview: status, last run, open tasks, next scheduled run  
  \- Tasks board: Backlog, Planned, In Progress, Blocked, Done  
  \- Agents: assigned agents, agent notes, quick actions  
  \- Files: output folders, artifacts, recent files  
  \- Activity timeline: task events, scheduler runs, chat summaries

B) Tasks  
\- Task types  
  1\. Plan task (research, PRD, roadmap)  
  2\. Build task (feature build, bug fix, implementation)  
  3\. Ops task (monitoring, outreach, reporting, recurring maintenance)  
\- Task fields  
  \- Title, description, type, priority, status, due date  
  \- Project, assignee agent, dependencies  
  \- Links: docs, URLs  
  \- Output folder pointer and expected deliverables checklist  
\- Task execution  
  \- “Run task” button that triggers an OpenClaw run via a backend command integration (see integration section below)  
  \- Store logs, start and end timestamps, exit status  
  \- Capture produced artifacts list (scan output folder before and after run, then diff)

C) Agents and sub agents  
\- Agents index page  
  \- Show all agents discovered from \~/.openclaw/openclaw.json  
  \- Show which projects use which agents  
  \- Notes and capabilities fields (editable in Control Center DB, not written back to openclaw.json unless explicitly enabled later)  
\- Per project “agent loadout”  
  \- Define which agent is primary and which are sub agents  
  \- Quick “chat as agent” from the project context

D) Scheduler (cron job setup area)  
\- Scheduler page  
  \- List jobs: name, project, schedule (cron expression), enabled, last run, next run  
  \- Create job wizard  
    \- Select project  
    \- Select job type: run task, run agent prompt, run maintenance script  
    \- Cron expression builder plus raw input  
    \- “Run now” button  
  \- Execution log history for each job  
\- Implementation detail  
  \- Use a Node scheduler (like node-cron) that is always on while backend is running  
  \- Save schedules to SQLite, reload on startup  
  \- Add safe guards to prevent overlapping runs unless explicitly allowed  
  \- Provide timezone handling and show timezone clearly in UI

E) Web chat (per project)  
\- Chat UI inside each project  
  \- Select agent  
  \- Chat messages stream in real time  
  \- Include context badges: project, selected task (optional), selected files (optional)  
  \- Provide “Send output to task notes” and “Create task from chat”  
\- Minimal chat memory  
  \- Store chat sessions per project in SQLite  
  \- Provide searchable chat history  
  \- Allow exporting a chat session to a markdown file in the project output directory

F) Files and outputs  
\- Files tab per project  
  \- Show output directory tree  
  \- Search filenames and basic text search for small files  
  \- “Open folder” action  
  \- “Copy path” action  
  \- “Attach file to task” and “Link file to task”  
\- Artifact indexing  
  \- Background indexing process (local) that updates recent files list and simple metadata  
  \- Must not read secrets or scan outside configured directories

G) Global Mission Control dashboard  
\- Home screen widgets  
  \- Active tasks across all projects  
  \- Next scheduled runs  
  \- Recent task completions  
  \- Projects with blockers  
  \- Quick create: project, task, scheduler job  
\- A command palette (Ctrl K)  
  \- Jump to project  
  \- Create task  
  \- Run task  
  \- Open output folder

Integration details (how to run OpenClaw)  
\- Implement an adapter layer with 2 modes  
  Mode 1: Stub mode (for early development)  
  \- Running a task simulates progress and writes a fake log

  Mode 2: Real OpenClaw integration  
  \- Provide a backend setting where I specify the OpenClaw CLI command and working directory  
  \- The system runs a child process, streams stdout and stderr to the UI, saves logs to disk and DB  
  \- Store per project run configuration: cwd, env var references, output folder  
\- Safety  
  \- Validate all paths against allowlisted project roots  
  \- Do not allow arbitrary shell commands from the UI  
  \- Only allow running predefined templates and known OpenClaw commands  
  \- Provide an “admin settings” page to manage allowlists

Security and privacy  
\- Local only by default  
  \- Bind backend to 127.0.0.1  
  \- Add an optional basic auth toggle for LAN  
\- Secrets  
  \- Do not store API keys in SQLite in plain text  
  \- Provide a way to reference environment variables  
  \- Provide a settings page that shows which env vars are required per project

UX and design requirements  
\- Polished mission control style UI  
\- Fast navigation, minimal clutter  
\- Clear project separation  
\- Consistent components, good spacing, modern look  
\- Dark mode optional but preferred

Deliverables required from you (agent)  
1\) A product spec  
  \- User stories  
  \- Screens list  
  \- Navigation map  
  \- Data model  
  \- Permissions model (even if simple)  
  \- Edge cases

2\) A technical design doc  
  \- Architecture diagram (described in text)  
  \- API routes list  
  \- DB schema (tables and key fields)  
  \- WebSocket events  
  \- Scheduler design  
  \- File indexing approach  
  \- OpenClaw integration adapter approach  
  \- Security considerations and path validation strategy

3\) Implementation plan  
  \- Milestones (at least 5\)  
  \- Each milestone includes specific tickets  
  \- Identify what can be stubbed first  
  \- Identify what needs real integration later

4\) A working MVP implementation  
  \- Repo structure  
  \- Backend server with SQLite  
  \- Frontend dashboard with routing  
  \- Projects CRUD  
  \- Tasks board CRUD  
  \- Scheduler CRUD with node-cron  
  \- Chat UI with stub streaming  
  \- File browser for output directories  
  \- WebSocket live updates for task runs  
  \- Basic settings page for OpenClaw config path and allowlists

Acceptance criteria  
\- I can create a project in under 60 seconds  
\- I can create tasks and move them across statuses with drag and drop  
\- I can click “Run task” and see streaming logs and status updates  
\- I can create a scheduled job and it runs at the next schedule  
\- I can open the output folder for a project from the UI  
\- I can chat with an agent in a project context and save the chat to a task note  
\- The app runs locally with a single command and persists data across restarts

Constraints and quality bar  
\- Prefer simple, reliable choices over flashy ones  
\- Strong input validation throughout  
\- Handle errors with helpful messages  
\- No em dashes anywhere in UI text, logs, or docs  
\- Provide meaningful sample data for demo

Now do the following, in order  
Step 1: Ask any critical questions only if truly blocking. Otherwise assume sensible defaults.  
Step 2: Produce the product spec and technical design doc.  
Step 3: Produce the implementation plan with milestones and tickets.  
Step 4: Generate the initial codebase with clear instructions to run locally.  
Step 5: List immediate next improvements after MVP.

Output format  
\- Use clear headings  
\- Use code blocks for schema, routes, and commands  
\- Provide copy paste run commands  
\- Keep docs and code consistent

Start now.

Phase 2: Wiring back end (100 hours to build this)

You are my senior full stack engineer and systems architect.

Project: OpenClaw Mission Control  
Current Status: The app is already live and running at http://localhost:3001/

Important:  
\- This is NOT a greenfield build.  
\- Do NOT rebuild the project from scratch.  
\- We are refactoring, wiring, and upgrading the existing live app.  
\- Many UI sections currently show “Coming Soon”.  
\- Buttons exist but are not wired to backend logic.  
\- We must turn this into a fully functional Mission Control.

Primary Goal  
Modernize the UI to feel futuristic and then wire every function end to end so that:  
\- Projects  
\- Tasks  
\- Agents  
\- Task runs  
\- Scheduler / cron jobs  
\- Logs  
\- Files  
\- Web chat  
\- Streaming updates

…are all real and integrated with OpenClaw.

This must operate locally and integrate with:  
\~/.openclaw/openclaw.json

\========================================  
PHASE 1: CODEBASE AUDIT  
\========================================

Before changing anything:

1\. Inspect the running app architecture:  
   \- Frontend framework  
   \- Backend framework  
   \- DB layer  
   \- WebSocket implementation  
   \- Routing structure  
   \- Current schema

2\. Identify:  
   \- Which UI components are placeholders  
   \- Which buttons lack onClick handlers  
   \- Which handlers exist but lack backend endpoints  
   \- Which endpoints exist but do not persist  
   \- Which backend services are stubs  
   \- Where “Coming Soon” is hardcoded

3\. Produce:  
   \- A wiring gap report  
   \- A list mapping UI actions → missing backend logic  
   \- A list mapping backend endpoints → missing DB writes  
   \- A list mapping OpenClaw integration points → not implemented

Do NOT skip this audit.

\========================================  
PHASE 2: WIRING PLAN  
\========================================

Create a full wiring map:

For every major feature, define:

UI Action  
→ API Route  
→ DB Mutation  
→ OpenClaw Adapter Action  
→ WebSocket Event  
→ UI State Update

Cover:

1\) Projects CRUD  
2\) Tasks CRUD \+ drag and drop status changes  
3\) Run Task button  
4\) Agent discovery from \~/.openclaw/openclaw.json  
5\) Assign agents to project  
6\) Scheduler create / enable / disable / run now  
7\) Task run log streaming  
8\) Web chat streaming  
9\) File browser \+ open folder action

Nothing may remain unconnected.

\========================================  
PHASE 3: OPENCLAW ADAPTER (REAL)  
\========================================

Implement a backend OpenClaw adapter layer.

Requirements:

\- Read \~/.openclaw/openclaw.json  
\- Discover available agents  
\- Allow per project configuration:  
    cwd  
    output directory  
    selected agent  
    environment references

\- Execute OpenClaw via child\_process  
\- Stream stdout/stderr via WebSocket  
\- Persist logs to disk  
\- Persist run records to DB  
\- Support cancellation  
\- Strict path validation  
\- No arbitrary command execution

All execution must:  
\- Be allowlisted  
\- Validate project root boundaries  
\- Bind backend to 127.0.0.1

\========================================  
PHASE 4: SCHEDULER SYSTEM  
\========================================

Implement real cron functionality.

\- node-cron or equivalent  
\- Jobs stored in SQLite  
\- Reload on server restart  
\- Prevent overlapping runs per project by default  
\- Record:  
    job started  
    job completed  
    job failed  
\- WebSocket updates for scheduler runs

UI must allow:  
\- Create job  
\- Edit cron expression  
\- Enable/disable  
\- Run now  
\- View history  
\- See next run time

\========================================  
PHASE 5: WEB CHAT (REAL)  
\========================================

Implement per-project chat.

\- Select agent  
\- Stream responses live  
\- Store chat sessions  
\- Allow:  
    Save to task notes  
    Create task from chat  
    Export to markdown in project output folder

If OpenClaw chat endpoint exists, use it.  
If not, create a ChatAdapter interface that uses OpenClaw CLI mode.

No “Coming Soon”.  
Chat must function.

\========================================  
PHASE 6: FILES SYSTEM  
\========================================

Implement per-project file browser.

\- Tree view  
\- Filename search  
\- Preview small text files  
\- Copy path  
\- Open folder via backend command  
\- Link file to task

Must validate all paths.

\========================================  
PHASE 7: FUTURISTIC UI MODERNIZATION  
\========================================

Upgrade visual design without breaking wiring.

Requirements:

\- Dark mode default  
\- Subtle glow accents  
\- Glass panels  
\- Clean typography scale  
\- Animated state transitions  
\- Real time indicators  
\- Command palette (Ctrl K) wired  
\- No clutter  
\- No em dashes anywhere

Do not introduce performance issues.

UI must feel like:  
“AI Operations Command Center”

\========================================  
DATABASE REQUIREMENTS  
\========================================

Ensure schema supports:

Projects  
Tasks  
TaskRuns  
Agents  
ProjectAgents  
SchedulerJobs  
SchedulerRuns  
ChatSessions  
ChatMessages  
Settings  
Artifacts

Provide final schema.

\========================================  
ACCEPTANCE CRITERIA  
\========================================

Every button works.  
Every section is functional.  
No placeholder text remains.  
Task runs stream logs live.  
Scheduler executes and logs.  
Agents load from openclaw.json.  
Chat streams and saves.  
Files browser works.  
App persists across restart.  
Dashboard shows real data.

\========================================  
OUTPUT FORMAT  
\========================================

1\) Audit report  
2\) Wiring map  
3\) Updated architecture  
4\) Final DB schema  
5\) Milestone plan (at least 6\)  
6\) Implementation tasks  
7\) Smoke test checklist  
8\) UI modernization spec

Do not rebuild from scratch.  
Upgrade and wire the existing live system.

Start with the audit. Respond back with an estimate of cost and token usage.

[image1]: <data:image/png;base64,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>