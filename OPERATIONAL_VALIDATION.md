# NovaOps -- Operational Validation Guide

This guide provides a step-by-step framework to validate the deployment, architectural integrity, and incident response performance of NovaOps v2 in a production-ready environment.

---

## Value Proposition

**The Challenge:** Traditional incident response at 3 AM is manual, slow, and error-prone. SREs spend critical time gathering context across fractured stacks while services remain degraded.

**The Solution:** NovaOps v2 is an autonomous SRE Control Plane powered by Amazon Nova 2. It orchestrates a dual-pipeline investigation that:
1. Dispatches parallel domain experts (Logs, Metrics, K8s, GitHub).
2. Synthesizes a verifiable root cause and remediation protocol.
3. Validates the plan through an independent **Consensus Engine**.
4. Enforces safety through a **Governance Gate** and real-time voice verification.

---

## Operational Readiness Checklist

Before operationalizing NovaOps, ensure the following prerequisites are met:

1. **AI Infrastructure**: Professional AWS Bedrock access for Amazon Nova 2 models.
2. **Persistence Layer**: Scalable DynamoDB (LocalStack or AWS) for incident history.
3. **Artifact Storage**: S3 buckets for Post-Incident Reports (PIR).
4. **Control Plane**: Operational backend API (`docker compose up -d`).
5. **Human-in-the-Loop**: Configured Amazon Connect or Slack for critical escalation.

---

## Deployment Validation Scenarios

### Scenario 1: Infrastructure Isolation & Analysis

Validate that NovaOps can autonomously investigate and remediate resource exhaustion.

1. **Trigger**: Execute `simulate_incident.sh` (or `trigger_live_outage.sh`).
2. **Observation**: Monitor the **Consensus Dashboard** (`http://localhost:8082/dashboard/`).
3. **Verification**: 
   - Confirm parallel dispatch of specialized agents.
   - Observe the **Consensus Engine** deliberating independently on raw system telemetry.
   - Verify the **Governance Gate** calculating risk scores based on policy.

### Scenario 2: High-Severity Escalation

Test the real-time voice escalation path for critical P1 incidents.

1. **Action**: Ensure `NOVAOPS_VOICE_USE_MOCK=false` for live testing (or `true` for protocol validation).
2. **Process**: When the scenario hits the risk threshold, verify an outbound call triggers via Amazon Connect.
3. **Approval**: Speak with the Nova real-time agent to approve the remediation verbally.
4. **Audit**: Verify the path from verbal approval to automated execution is logged in the append-only audit trail.

### Scenario 3: Post-Mortem Generation

Confirm the automated generation of professional compliance artifacts.

1. **Action**: Complete a validation scenario.
2. **Artifact**: Click "Post-Incident Report" in the UI.
3. **Verification**: Confirm a structured PDF is generated via Amazon Nova and archived to S3.

---

## Technical Architecture Highlights

- **Parallel Orchestration**: Concurrent agent execution minimizes Time-To-Mitigate (TTM).
- **Independent Consensus**: Prevents architectural groupthink by separating primary investigation from validation logic.
- **Plug-and-Play Integration**: LocalStack integration allows for full offline testing before flipping to production AWS infrastructure.
- **Audit Compliance**: Every decision is traceable, validated against schemas, and stored in non-repudiable logs.
