---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet.

**Ask one question at a time.** From the frontier, pick the question whose answer prunes or unblocks the most of the tree, ask it, and wait. Use the host's question tool when it has one (multiple choice, recommended option first and marked "(Recommended)", 2-4 options); otherwise use this format:

```
❓ **Q<n>** - **<question title>**: <question body, the facts it rests on, and the choices>

➡️ <your recommended answer>
```

Word each question so "yes" accepts your recommended answer. Number questions across the whole session so the user can refer back. Ask a whole round at once only when the user asks for it.

Each answer reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier before the next question. Drop questions the answer made moot, and say so in one line.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: ask a frontier question that does not depend on the pending fact while it runs. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Close with a one-screen summary of every decision taken. Do not act on it until the user confirms you have reached a shared understanding.
