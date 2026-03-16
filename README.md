# NovaOps

**Autonomous multi-agent SRE war room powered by Amazon Nova 2 Lite — with independent jury validation.**

NovaOps v2 responds to production alerts end-to-end: it triages the incident, dispatches four specialist analysts in parallel, reasons over their findings, validates the reasoning path with an adversarial critic, then runs a completely independent jury validation before gating the action through a policy engine. Every decision is logged to an append-only audit trail. Human override is always available.

Built for Enterprise scale incident management using Amazon Nova foundational models.

---

## Latest Release Features

- **Enterprise-Grade Architectural Rebranding**: Transitioned conceptually to a Consensus-driven validation model featuring the **Consensus Engine** and **Independent Validators**, supported by a new professional **Onboarding & Operational Validation** guide.
- **Enhanced Operational Stability & Hardening**: Implemented self-healing system startups, robust cross-environment `kubectl` orchestration, and high-fidelity failure investigation logging for 100% visibility in the telemetry dashboard.
- **Critical Incident Voice Escalation via Amazon Connect**: Outbound phone calls to on-call engineers for critical incidents (P1 / high risk score), powered by Amazon Nova real-time conversation through a Lex + Lambda bridge. Verbal approval triggers remediation through the existing governance gate. Falls back to Slack critical escalation if the call fails.
- **Escalation Policy Engine**: Configurable severity and risk-score thresholds determine which incidents trigger voice escalation vs standard Slack notification. Auto-executed incidents are automatically skipped.
- **Slack Critical Escalation**: High-visibility fallback Slack messages with call status, escalation reasons, and approval buttons — sent alongside or instead of the phone call.
- **Amazon Nova Sonic Integration**: Live, real-time simulated voice calls via AWS Bedrock for human-in-the-loop action approval.
- **Unified Telemetry Dashboard**: Complete, colorized logging of all War Room, Jury, and API operations piped directly into a single `novaops_system.log` stream.

---

## How It Works

The pipeline has three stages. The War Room and the Jury run independently — the Jury never sees the War Room's reasoning. Their conclusions are compared in the Convergence Check before the Governance Gate makes the final call.

```
Alert (POST /webhook/pagerduty)
  │
  ▼
┌──────────────────────────────────────────────────────────┐
│  STAGE 1: WAR ROOM  (deep sequential investigation)      │
│                                                          │
│  Triage Agent          classifies domain, severity, svc  │
│    │                                                     │
│    ├── Log Analyst ────────────────────────┐             │
│    ├── Metrics Analyst ────────────────────┤ parallel    │
│    ├── K8s Inspector ──────────────────────┤             │
│    └── GitHub Analyst ─────────────────────┘             │
│    │                                                     │
│  Root Cause Reasoner   synthesises findings              │
│    │                                                     │
│  Critic Agent          adversarial review, loop x3 max   │
│    │                                                     │
│  Remediation Planner   proposes rollback/scale/restart   │
└────────────────────────────┬─────────────────────────────┘
                             │ proposed_action + domain
                             │
                             │ raw context only (no war room reasoning)
                             ▼
┌──────────────────────────────────────────────────────────┐
│  STAGE 2: JURY VALIDATION  (independent blind panel)     │
│                                                          │
│  4 specialist jurors deliberate in parallel              │
│  on raw incident context — no war room influence         │
│                                                          │
│  ┌────────────────┐  ┌──────────────────────────────┐   │
│  │ Log Analyst    │  │ Infra Specialist              │   │
│  │ logs, OOM,     │  │ K8s pod health, CPU/mem       │   │
│  │ crash traces   │  │ OOMKilled, scaling signals    │   │
│  └────────────────┘  └──────────────────────────────┘   │
│  ┌────────────────┐  ┌──────────────────────────────┐   │
│  │ Deploy         │  │ Anomaly Specialist            │   │
│  │ Specialist     │  │ Layer 1: RAG signal           │   │
│  │ git commits,   │  │ Layer 2: regex pattern scan   │   │
│  │ config regs    │  │ Layer 3: LLM residual         │   │
│  └────────────────┘  └──────────────────────────────┘   │
│                │                                         │
│             Judge LLM — synthesises 4 verdicts           │
│             Escalation Gate — 6 safety checks            │
└────────────────────────────┬─────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────┐
│  STAGE 3: CONVERGENCE CHECK                              │
│                                                          │
│  War Room action == Jury action?                         │
│                                                          │
│  AGREE  + no jury escalation                            │
│    → confidence boosted (+0.15)                          │
│    → GovernanceGate may ALLOW_AUTO                       │
│                                                          │
│  DISAGREE or jury escalation                             │
│    → confidence penalised (-0.30)                        │
│    → GovernanceGate forces REQUIRE_APPROVAL              │
│    → Slack shows both perspectives with full reasoning   │
└────────────────────────────┬─────────────────────────────┘
                             │ adjusted_confidence
                             ▼
┌──────────────────────────────────────────────────────────┐
│  GOVERNANCE GATE                                         │
│  Risk score + policy → ALLOW_AUTO | REQUIRE_APPROVAL     │
│  Audit trail updated with CONVERGENCE_CHECK event        │
└──────────────────────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────┐
│  EXECUTION & APPROVAL                                    │
│                                                          │
│  ALLOW_AUTO ───────► Auto-Remediate (K8s API)            │
│  REQUIRE_APPROVAL ─► Escalation Policy Check             │
│    ├─ CRITICAL ────► Amazon Connect Outbound Call         │
│    │                 (Nova real-time voice via Lex/Lambda)│
│    │                 + Slack Critical Escalation          │
│    └─ NORMAL ──────► Slack Ghost Mode Notification       │
└──────────────────────────────────────────────────────────┘
```

All agent outputs are validated against typed schemas and written to `plans/{incident_id}/` as inspectable JSON artifacts.

---

## Why Two Pipelines?

The War Room and Jury solve different failure modes:

| Risk | War Room alone | Jury alone | Hybrid |
|---|---|---|---|
| Triage misclassifies domain | Propagates to all agents | Immune | Jury catches blind spot |
| Weak hypothesis | Critic may catch it | No self-correction | Critic + independent jury |
| Confident but wrong | Passes gate | Passes gate | Both must agree |
| Unknown / external incident | Anomaly specialist | Anomaly specialist | Double-validated |

The **key design principle**: jurors receive only the raw incident context — not the War Room's reasoning. This preserves full independence and prevents groupthink.

---

## Governance

Every proposed remediation passes through a policy engine before execution.

**Risk score (0-100):**
- Action weight: rollback=40, restart=20, scale=15, noop=0
- Severity weight: P1=30, P2=20, P3=10, P4=5
- Confidence penalty: `max(0, (0.75 - confidence) * 40)` for low-confidence decisions

When the Convergence Check runs, the adjusted confidence replaces the raw war room confidence in the risk calculation. In addition, `GovernanceGate` applies a hard guard: disagreement or jury escalation always resolves to `REQUIRE_APPROVAL`.

**Policy decisions (first match wins):**

| Policy | Condition | Decision |
|---|---|---|
| noop_requires_approval | action=noop | REQUIRE_APPROVAL |
| p1_always_requires_approval | severity=P1 | REQUIRE_APPROVAL |
| rollback_always_requires_approval | action=rollback | REQUIRE_APPROVAL |
| low_confidence_escalate | confidence < 0.65 | REQUIRE_APPROVAL |
| high_confidence_p3_p4_auto | P3/P4 + restart/scale + conf >= 0.75 | ALLOW_AUTO |
| p2_scale_high_confidence | P2 + scale + conf >= 0.85 | ALLOW_AUTO |
| default_require_approval | (catch-all) | REQUIRE_APPROVAL |

**Confidence precedence:**
`convergence.adjusted_confidence > critic.confidence > root_cause.confidence_overall > top_hypothesis.confidence > 0.0`

**Artifacts written per incident:**
- `governance.json` — full decision record
- `governance_report.md` — human-readable summary with risk bar and audit table
- `audit.jsonl` — append-only event log including `CONVERGENCE_CHECK` event

---

## Audit Trail Events

Every incident generates a complete, ordered audit trail in `plans/{incident_id}/audit.jsonl`:

| Event | Actor | When |
|---|---|---|
| `ALERT_RECEIVED` | SYSTEM | Webhook received |
| `TRIAGE_COMPLETE` | SYSTEM | Domain, severity, service classified |
| `HYPOTHESIS_FORMED` | SYSTEM | Root cause ranked |
| `CRITIC_VERDICT` | SYSTEM | Adversarial review completed |
| `CONVERGENCE_CHECK` | SYSTEM | War Room vs Jury compared |
| `GOVERNANCE_DECISION` | SYSTEM | Policy evaluated, risk scored |
| `EXECUTION_STARTED` | SYSTEM/HUMAN | Tool execution begins |
| `EXECUTION_COMPLETE` | SYSTEM/HUMAN | Tool execution result |
| `HUMAN_OVERRIDE` | HUMAN | Manual approval via `/approve` |
| `HUMAN_REJECTED` | HUMAN | Manual denial via `/reject` |

---

## Voice Escalation (Amazon Connect + Nova Real-Time)

Critical incidents trigger an outbound phone call to the on-call engineer via Amazon Connect. The call is powered by a Nova real-time conversation through a Lex V2 bot backed by a Lambda function.

**How it works:**

```text
trigger_agent_loop() completes investigation
  → escalation_policy.evaluate(severity, risk_score)
    → if critical:
        1. build_briefing_script()   — ≤60-word TTS script
        2. build_system_prompt()     — full Nova conversation context
        3. connect_caller.place_call() → Amazon Connect dials on-call
           → Contact Flow plays briefing via Polly TTS
           → Lex bot captures engineer's speech
           → Lambda calls bedrock.converse() with Nova
           → Nova detects [ACTION_APPROVED] / [ACTION_REJECTED]
           → Lambda POSTs to /api/incidents/{id}/approve or /api/incidents/{id}/reject
        4. Slack critical escalation sent (supplement or fallback)
        5. voice_escalation.json artifact saved to plans/{id}/
```

**Escalation criteria (configurable via env vars):**

- Severity in `CRITICAL_SEVERITY_LEVELS` (default: `P1`)
- Risk score >= `CRITICAL_RISK_SCORE_THRESHOLD` (default: `85`)
- Either condition triggers escalation; auto-executed incidents are skipped

**Ghost Mode preserved:** The phone call informs the engineer and asks for verbal approval. Approval flows through `GovernanceGate.approve_and_execute()` with `HUMAN_OVERRIDE` logged to the audit trail — same path as dashboard or Slack approval.

**Fallback safety:** If the outbound call fails (Connect error, no answer, misconfigured), Slack critical escalation fires with `call_failed=True` so the incident is never dropped.

**AWS setup required for production:**

1. Create an Amazon Connect instance with an outbound phone number
2. Create a Contact Flow that plays the `briefing_script` attribute via Polly, then routes to a Lex V2 bot
3. Create a Lex V2 bot with a `VoiceEscalation` intent, fulfillment pointed at the Lambda
4. Deploy `lambda_handlers/nova_connect_handler.py` as an AWS Lambda function
5. Set env vars: `CONNECT_INSTANCE_ID`, `CONNECT_CONTACT_FLOW_ID`, `CONNECT_SOURCE_PHONE`, `ONCALL_PHONE_NUMBER`, `NOVAOPS_VOICE_USE_MOCK=false`

**Mock mode:** Set `NOVAOPS_VOICE_USE_MOCK=true` (default) to log calls instead of dialing. All escalation logic runs — only the Connect API call is skipped.

---

## Repository Layout

```
agents/         War Room orchestration graph, prompts, schemas, artifacts, PIR generation
Agent_Jury/     Jury pipeline — 4 specialist jurors + Judge + Escalation Gate
  jurors/       Log Analyst, Infra Specialist, Deployment Specialist, Anomaly Specialist
agent/          nova_client.py — Bedrock client used by Jury jurors
pipeline/       convergence.py — War Room vs Jury agreement check
aggregator/     Log, metric, Kubernetes, and GitHub data fetchers (live + mock)
api/            FastAPI server, history DB, Slack notifier, escalation policy, voice summary, Connect caller
lambda_handlers/ Lambda function for Lex V2 fulfillment — bridges phone audio to Nova real-time
governance/     GovernanceGate, PolicyEngine, AuditLog, report generator
tools/          Tool wrappers, RemediationExecutor, knowledge retrieval
evaluation/     15 scenario harness covering 6 failure domains
skills/         Domain playbooks (oom, traffic_surge, deadlock, config_drift, ...)
runbooks/       Learned PIR content for RAG
plans/          Generated investigation artifacts (git-ignored)
tests/          124 unit + integration tests
```

---

## Quick Start (Zero-Install)

The entire NovaOps environment runs inside isolated Docker containers (including a K3s Kubernetes cluster). You only require `docker` and `docker compose` installed on your machine.

### Environment Setup (`.env`)
Create a `.env` file in the root directory with your AWS credentials. These are used by the proxy to talk to Bedrock.

```bash
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_DEFAULT_REGION=us-east-1
NOVA_MODEL_ID=us.amazon.nova-2-lite-v1:0
SERVICE_REPO_MAP='{"payment-service":{"owner":"acme","repo":"payment-api"},"order-service":{"owner":"acme","repo":"order-api"},"inventory-service":{"owner":"acme","repo":"inventory-api"},"auth-service":{"owner":"acme","repo":"auth-api"},"user-service":{"owner":"acme","repo":"user-api"},"dummy-service":{"owner":"acme","repo":"dummy-api"}}'
```

---

## Operations Guide

This section outlines the standard procedures for launching the isolated environment and safely executing automated failure injection for SRE validation purposes.

### 1. Initialize the Environment
Launch the backend services (API, LocalStack, and K3s) through Docker Compose. All components are self-contained.
```bash
./start_war_room.sh
```
*Wait ~15 seconds for Kubernetes components to initialize. Monitor via `docker compose logs -f`.*

### 2. Automated Runbook Verification (Simulated Incidents)
To validate the system's reasoning engine across the full incident schema (OOM, Deadlock, Traffic Surge, Cascading Failure, Config Drift), invoke the evaluation suite.
```bash
./run_simulations.sh
```
*Verification results are recorded automatically to the telemetry dashboard at `http://localhost:8082/dashboard/`.*

### 3. Live Failure Injection Validation
To continuously validate the host integration with the live Kubernetes daemon, invoke the synthetic OOM failure script. This forces an out-of-memory exception on a targeted pod for agent validation.
```bash
./trigger_live_outage.sh
```

### 4. Teardown
To cleanly de-allocate all resources, persistent volumes, and Docker networks:
```bash
./stop_war_room.sh
```

- Dashboard: `http://localhost:8082/`
- API docs (Swagger): `http://localhost:8082/docs` (served via `/novaops.json`)

### API endpoints

```
POST /webhook/pagerduty           — trigger full 3-stage investigation
GET  /api/incidents               — list recent incidents (dashboard feed)
GET  /api/incidents/{id}          — fetch status + artifacts
POST /api/incidents/{id}/approve  — human approval → governance gate → execution
POST /api/incidents/{id}/reject   — human rejection → record audit + governance artifact
POST /slack/actions               — Slack interactive callbacks (approve/reject buttons)
GET  /api/governance/{id}/decision
GET  /api/governance/{id}/audit
```

`POST /webhook/pagerduty` supports optional metadata for jury repo context:

```json
{
  "alert_name": "P2 latency alert",
  "service_name": "checkout-service",
  "namespace": "prod",
  "description": "traffic surge in checkout",
  "metadata": {
    "github": {
      "owner": "acme-inc",
      "repo": "checkout-api"
    }
  }
}
```

---

## Storage Backends

NovaOps v2 uses a dual-backend design for incident history:

| Environment | Backend | How selected |
|---|---|---|
| Local uvicorn | SQLite (`history.db`) | `DYNAMODB_ENDPOINT` not set |
| Docker / LocalStack | DynamoDB via LocalStack | `DYNAMODB_ENDPOINT=http://localstack:4566` |

The factory function `get_incident_db()` in `api/history_db.py` automatically selects the correct backend based on the `DYNAMODB_ENDPOINT` environment variable. Both backends expose an identical interface (`log_incident`, `get_incident`, `update_status`, `save_pir`, `get_recent_incidents`).

In Docker, LocalStack initialises the DynamoDB table on first use (lazy init — no startup blocking). The S3 bucket `novaops-pir-reports` is created by `init-aws.sh` which LocalStack runs automatically when ready.

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `NOVAOPS_USE_MOCK` | `true` | Offline mode — no Bedrock calls, controls War Room and Jury |
| `NOVA_MODEL_ID` | `us.amazon.nova-2-lite-v1:0` | Bedrock inference profile |
| `AWS_DEFAULT_REGION` | `us-east-1` | Bedrock / LocalStack region |
| `AWS_BEARER_TOKEN_BEDROCK` | — | Bearer token for Bedrock access |
| `LOCAL_EVAL_MODE` | `false` | Alias for mock mode |
| `SLACK_WEBHOOK_URL` | — | Ghost Mode approval notifications |
| `SLACK_SIGNING_SECRET` | — | Slack signing secret for interactive approve/reject callbacks (`POST /slack/actions`) |
| `USE_BEDROCK_KB` | `false` | Use managed Bedrock Knowledge Bases for RAG |
| `DYNAMODB_ENDPOINT` | — | Set to LocalStack URL in Docker; selects DynamoDB backend |
| `S3_ENDPOINT` | — | Set to LocalStack URL in Docker; used for PIR PDF presigned URLs |
| `NOVAOPS_LOG_PATH` | `novaops.log` | Path to the unified log file read by the dashboard live terminal |
| `NOVAOPS_APPROVAL_TOKEN` | — | If set, approvals require `X-NovaOps-Approval-Token` |
| `NOVAOPS_CORS_ORIGINS` | `http://localhost:8082,...` | CORS allowlist (JSON array or comma-separated) |
| `HISTORY_DB_PATH` | `history.db` | Override SQLite file path (local only) |
| `SERVICE_REPO_MAP` | — | JSON map for jury GitHub context. Example: `{"checkout-service":{"owner":"acme-inc","repo":"checkout-api"}}` |
| **Voice Escalation** | | |
| `NOVAOPS_VOICE_ESCALATION_ENABLED` | `true` | Master switch for critical voice escalation |
| `NOVAOPS_VOICE_USE_MOCK` | `true` | Mock mode — logs calls instead of dialing |
| `CRITICAL_SEVERITY_LEVELS` | `P1` | Comma-separated severities that trigger voice escalation |
| `CRITICAL_RISK_SCORE_THRESHOLD` | `85` | Risk score at or above which voice escalation triggers |
| `CONNECT_INSTANCE_ID` | — | Amazon Connect instance ID |
| `CONNECT_CONTACT_FLOW_ID` | — | Contact Flow ID for voice escalation |
| `CONNECT_SOURCE_PHONE` | — | Outbound caller ID (E.164, e.g. `+15551234567`) |
| `ONCALL_PHONE_NUMBER` | — | On-call engineer's phone number (E.164) |
| `NOVAOPS_API_CALLBACK_URL` | `http://localhost:8082` | URL the Lambda calls to approve/reject incidents |

Slack approvals: `SLACK_WEBHOOK_URL` controls message delivery; approve/reject button clicks require Slack Interactivity with Request URL pointing to `POST /slack/actions` and `SLACK_SIGNING_SECRET` set.

---

## Evaluation

```bash
python -m evaluation --list          # show all 15 scenarios
python -m evaluation --scenario 1    # run one scenario
python -m evaluation --domain oom    # run all OOM scenarios
python -m evaluation --all           # run full suite
```

Scenarios cover: `oom`, `traffic_surge`, `deadlock`, `config_drift`, `dependency_failure`, `cascading_failure`.

---

## Tests

```bash
python -m unittest discover -s tests -v
# 124 tests (unit + integration)
```

---

## Artifacts

Each investigation writes to `plans/{incident_id}/`:

| File | Contents |
|---|---|
| `report.md` | Full investigation report |
| `governance.json` | Policy decision, risk score, confidence, convergence source |
| `governance_report.md` | Human-readable governance summary |
| `audit.jsonl` | Append-only event log including CONVERGENCE_CHECK |
| `structured.json` | Typed agent outputs |
| `validation.json` | Schema validation scores |
| `trace.json` | Failure metadata (if investigation failed) |
| `findings/*.json` | Per-agent structured findings |
| `plan.md` | Investigation plan (updated to COMPLETED) |
| `voice_escalation.json` | Voice escalation metadata — call status, briefing script, reasons |
