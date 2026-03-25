# Gaia-X Compliant Data Marketplace
## Implementation Gap Analysis: Blueprint vs MVD Baseline

**Project:** Fontys University of Applied Sciences - Dataspaces Project
**Document Version:** 1.0
**Date:** March 2026
**Authors:** Benjamin (FIWARE/EDC Infrastructure), Juul (IAM Lead), Georgi (EDC/Java), Dimitar (EDC/Testing)

---

## Executive Summary

This document provides a comprehensive gap analysis between the architectural blueprint requirements for a Gaia-X compliant Data Marketplace and the capabilities provided by the Eclipse EDC Minimum Viable Dataspace (MVD) baseline repository. It identifies what is already implemented, what requires adaptation, and what must be built from scratch across the five implementation phases.

**Overall Coverage:** The MVD provides approximately **60-65%** of the required functionality out of the box. The remaining work focuses on Gaia-X specific compliance features, custom policy functions, and infrastructure adaptation for the Fontys Netlab environment.

---

## Table of Contents

1. [Architecture Pillar Analysis](#1-architecture-pillar-analysis)
2. [Protocol and Standards Compliance](#2-protocol-and-standards-compliance)
3. [Infrastructure Requirements](#3-infrastructure-requirements)
4. [Phase-by-Phase Implementation Requirements](#4-phase-by-phase-implementation-requirements)
5. [Testing Scenario Requirements](#5-testing-scenario-requirements)

---

## 1. Architecture Pillar Analysis

### 1.1 Control Plane

| Requirement | Blueprint Specification | MVD Status | Gap |
|-------------|------------------------|------------|-----|
| DSP Protocol Implementation | Full Dataspace Protocol for contract negotiation | **COMPLETE** | None |
| Contract Negotiation State Machine | Asynchronous state transitions (REQUEST → OFFERED → AGREED) | **COMPLETE** | None |
| ODRL Policy Evaluation Engine | Native Java-based PolicyFunction evaluation | **PARTIAL** | Custom functions needed |
| JSON-LD Policy Parsing | Parse rules, permissions, prohibitions, obligations | **COMPLETE** | None |
| Management API | RESTful API for asset/contract management | **COMPLETE** | None |

**MVD Implementation Location:** `launchers/controlplane/`

**Gap Summary:** The Control Plane is fully functional. The only gap is registering custom PolicyFunction implementations for the specific ODRL constraints required by the blueprint (TimeIntervalUsage, RegionLocation).

---

### 1.2 Data Plane

| Requirement | Blueprint Specification | MVD Status | Gap |
|-------------|------------------------|------------|-----|
| High-volume Data Transfer | Asynchronous, scalable bit transfer | **COMPLETE** | None |
| HTTP Push/Pull | HTTP-based data transfer protocols | **COMPLETE** | None |
| Ephemeral Access Provisioning | Short-lived EDR token generation | **COMPLETE** | None |
| Endpoint Data Reference (EDR) | Token-based access with automatic revocation | **COMPLETE** | None |
| Storage Backend Extensibility | Support for multiple storage types | **COMPLETE** | None |

**MVD Implementation Location:** `launchers/dataplane/`

**Gap Summary:** No gaps. The Data Plane is production-ready.

---

### 1.3 Identity Hub

| Requirement | Blueprint Specification | MVD Status | Gap |
|-------------|------------------------|------------|-----|
| Decentralized Claims Protocol (DCP) | Inter-node identity communication | **COMPLETE** | None |
| Verifiable Credential Storage | Enterprise-grade VC wallet | **COMPLETE** | None |
| Verifiable Presentation Construction | Aggregate VCs into signed VPs | **COMPLETE** | None |
| Presentation Exchange | Challenge-response VP flow | **COMPLETE** | None |
| DID Resolution | did:web method support | **COMPLETE** | Configuration needed |
| Secure Token Service (STS) | Token issuance for authenticated requests | **COMPLETE** | None |

**MVD Implementation Location:** `launchers/identity-hub/`

**Gap Summary:** The Identity Hub is complete. Configuration is required to:
- Generate new EC key pairs for Fontys participants
- Host did:web documents on Netlab infrastructure
- Configure DID resolution for the deployment environment

---

### 1.4 Federated Catalog

| Requirement | Blueprint Specification | MVD Status | Gap |
|-------------|------------------------|------------|-----|
| Catalog Crawler | Periodically scrape participant DSP endpoints | **COMPLETE** | None |
| DCAT Compliance | Standard catalog format | **COMPLETE** | None |
| Local Cache | Optimized query response | **COMPLETE** | None |
| Policy-Filtered Discovery | Only expose authorized assets | **COMPLETE** | None |

**MVD Implementation Location:** `launchers/catalog-server/`

**Gap Summary:** No gaps. Fully functional.

---

### 1.5 Data Dashboard (User Interface)

| Requirement | Blueprint Specification | MVD Status | Gap |
|-------------|------------------------|------------|-----|
| Administrative UI | Web interface for asset management | **NOT PROVIDED** | Full implementation needed |
| Management API Integration | Direct connection to EDC APIs | **NOT PROVIDED** | Full implementation needed |
| Contract Negotiation Monitoring | Visual state machine tracking | **NOT PROVIDED** | Full implementation needed |
| Federated Catalog Browser | Search and discover assets | **NOT PROVIDED** | Full implementation needed |

**MVD Approach:** Uses Postman collections and curl commands for API interaction.

**Gap Summary:** The blueprint requires an EDC Data Dashboard. MVD does not include this. Options:
1. Use the official [EDC Data Dashboard](https://github.com/eclipse-edc/DataDashboard) project
2. Build a custom React/Vue frontend
3. Accept Postman/API-only interaction for the project scope

**Recommendation:** Deploy the official EDC Data Dashboard as a separate container.

---

## 2. Protocol and Standards Compliance

### 2.1 Dataspace Protocol (DSP)

| Component | Blueprint Requirement | MVD Status | Notes |
|-----------|----------------------|------------|-------|
| Catalog Protocol | Asset discovery via DSP | **COMPLETE** | Standard implementation |
| Contract Negotiation Protocol | State machine for agreements | **COMPLETE** | Standard implementation |
| Transfer Process Protocol | Data transfer coordination | **COMPLETE** | Standard implementation |

**Gap:** None

---

### 2.2 Decentralized Claims Protocol (DCP)

| Component | Blueprint Requirement | MVD Status | Notes |
|-----------|----------------------|------------|-------|
| Scope Mapping | Map scopes to credential requirements | **COMPLETE** | Configured in `dcp-impl` |
| Presentation Exchange | VP request/response flow | **COMPLETE** | Standard implementation |
| Credential Verification | Validate VC signatures | **COMPLETE** | Standard implementation |

**Gap:** None

---

### 2.3 Decentralized Identifiers (DIDs)

| Component | Blueprint Requirement | MVD Status | Notes |
|-----------|----------------------|------------|-------|
| did:web Method | Web-hosted DID documents | **COMPLETE** | Used by all participants |
| DID Resolution | Resolve DIDs to DID Documents | **COMPLETE** | Custom resolver in extensions |
| Key Management | EC key pair generation/storage | **COMPLETE** | Vault-based in MVD |

**Gap:** Configuration needed for Netlab hostnames and Kubernetes Secrets (replacing Vault).

---

### 2.4 Verifiable Credentials (W3C)

| Credential Type | Blueprint Requirement | MVD Status | Gap |
|-----------------|----------------------|------------|-----|
| LegalParticipant | Gaia-X compliance credential | **NOT PROVIDED** | Must create issuer logic |
| MembershipCredential | Dataspace membership proof | **COMPLETE** | Standard in MVD |
| DataProcessorCredential | Data processing authorization | **COMPLETE** | Standard in MVD |
| CertifiedEnvironmentalResearcher | Role-based access credential | **NOT PROVIDED** | Must define schema + issuer |

**Gap Summary:** MVD uses generic credential types. The blueprint requires Gaia-X specific credentials:
- `gx:LegalParticipant` - Must adapt issuer service
- Custom role credentials - Must define JSON-LD schemas

---

### 2.5 ODRL Policy Evaluation

| Policy Type | Blueprint Requirement | MVD Status | Gap |
|-------------|----------------------|------------|-----|
| MembershipCredential Check | Verify dataspace membership | **COMPLETE** | `MembershipCredentialEvaluationFunction.java` |
| DataAccessLevel Check | Verify access tier credentials | **COMPLETE** | `DataAccessLevelFunction.java` |
| TimeIntervalUsage | Time-bound access windows | **NOT PROVIDED** | Must implement PolicyFunction |
| RegionLocation | Geographic processing constraints | **NOT PROVIDED** | Must implement PolicyFunction |

**Gap Summary:** Two custom Java PolicyFunction classes must be written:
1. `TimeIntervalUsageFunction.java` - Compare timestamps against system clock
2. `RegionLocationFunction.java` - Validate geographic claims from VPs

---

## 3. Infrastructure Requirements

### 3.1 Container Orchestration

| Component | Blueprint Requirement | MVD Default | Fontys Adaptation | Status |
|-----------|----------------------|-------------|-------------------|--------|
| Kubernetes Distribution | K3s (lightweight) | KinD | K3s | **COMPLETE** |
| Namespace | `mvd` | `mvd` | `mvd` | **COMPLETE** |
| Node Configuration | Single control-plane | Single node | Single node | **COMPLETE** |

---

### 3.2 Deployment Automation

| Component | Blueprint Requirement | MVD Default | Fontys Adaptation | Status |
|-----------|----------------------|-------------|-------------------|--------|
| Infrastructure as Code | Helm 3 | Terraform | Terraform + Helm | **COMPLETE** |
| CI/CD | GitHub Actions | GitHub Actions | GitHub Actions | **INHERITED** |

---

### 3.3 Ingress and Routing

| Component | Blueprint Requirement | MVD Default | Fontys Adaptation | Status |
|-----------|----------------------|-------------|-------------------|--------|
| External Ingress | Traefik | NGINX | Traefik | **COMPLETE** |
| Internal API Gateway | Apache APISIX | None | APISIX | **COMPLETE** |
| TLS Termination | At ingress layer | At ingress | At Traefik | **COMPLETE** |

---

### 3.4 Persistence

| Component | Blueprint Requirement | MVD Default | Fontys Adaptation | Status |
|-----------|----------------------|-------------|-------------------|--------|
| Relational Database | PostgreSQL | PostgreSQL | PostgreSQL | **COMPLETE** |
| Spatial Extensions | PostGIS | None | PostGIS | **COMPLETE** |
| PVC Storage | local-path | - | local-path | **COMPLETE** |

---

### 3.5 Secrets Management

| Component | Blueprint Requirement | MVD Default | Fontys Adaptation | Status |
|-----------|----------------------|-------------|-------------------|--------|
| Secret Storage | Kubernetes Secrets | HashiCorp Vault | K8s Secrets | **COMPLETE** |
| Key Management | kubectl | Vault API | kubectl | **COMPLETE** |

**Note:** Vault is optional hardening. K8s Secrets provide sufficient security for the project scope.

---

## 4. Phase-by-Phase Implementation Requirements

### Phase 1: Foundational Infrastructure (Weeks 1-3) - **COMPLETE**

| Task | Status | Deliverable |
|------|--------|-------------|
| K3s cluster deployment | **DONE** | Running cluster on Netlab |
| Traefik ingress installation | **DONE** | `traefik-values.yaml` |
| APISIX gateway installation | **DONE** | `apisix-values.yaml` |
| PostgreSQL/PostGIS deployment | **DONE** | `*-postgres.yaml` manifests |
| Kubernetes Secrets setup | **DONE** | `02-create-secrets.sh` |
| Base EDC deployment | **IN PROGRESS** | `edc-values.yaml` |

---

### Phase 2: Identity Layer and Mock Trust Anchor (Weeks 4-7) - **NOT STARTED**

| Task | Status | Deliverable |
|------|--------|-------------|
| EC key pair generation | **TODO** | Shell script with OpenSSL commands |
| did:web document creation | **TODO** | JSON DID documents per participant |
| DID document hosting | **TODO** | Nginx/static server deployment |
| Private key ingestion to K8s Secrets | **TODO** | kubectl commands in script |
| Mock Trust Anchor deployment | **TODO** | Deployment YAML + API |
| JSON-LD Self-Description drafting | **TODO** | Self-description JSON files |
| LegalParticipant VC issuance | **TODO** | Issuer API + VC templates |
| Identity Hub configuration | **TODO** | Helm values for Identity Hub |
| VC injection into Identity Hubs | **TODO** | DCP API calls |

**Dependencies:**
- Phase 1 must be complete (K8s cluster, secrets infrastructure)
- Requires understanding of MVD's existing issuer service

**Key Files to Create:**
```
deployment/k3s/identity/
├── scripts/
│   ├── generate-keys.sh          # OpenSSL EC key generation
│   └── create-did-documents.sh   # DID document generation
├── did-documents/
│   ├── provider.json
│   ├── consumer.json
│   └── issuer.json
├── self-descriptions/
│   ├── provider-sd.jsonld
│   ├── consumer-sd.jsonld
│   └── issuer-sd.jsonld
├── trust-anchor/
│   ├── deployment.yaml
│   └── vc-templates/
│       └── legal-participant.jsonld
└── identity-hub-values.yaml
```

---

### Phase 3: Policy Engine Configuration (Weeks 8-10) - **NOT STARTED**

| Task | Status | Deliverable |
|------|--------|-------------|
| TimeIntervalUsage PolicyFunction | **TODO** | Java class |
| RegionLocation PolicyFunction | **TODO** | Java class |
| PolicyFunction registry binding | **TODO** | Extension class |
| ODRL policy JSON-LD drafting | **TODO** | Policy JSON files |
| Unit tests for PolicyFunctions | **TODO** | JUnit test classes |
| Integration with Control Plane | **TODO** | Updated EDC build |

**Dependencies:**
- Phase 2 must be complete (VCs available for policy evaluation)
- Requires Java development environment

**Key Files to Create:**
```
extensions/policy-functions/
├── build.gradle.kts
├── src/main/java/org/gaiax/edc/policy/
│   ├── TimeIntervalUsageFunction.java
│   ├── RegionLocationFunction.java
│   └── GaiaXPolicyExtension.java
├── src/main/resources/
│   └── META-INF/services/
│       └── org.eclipse.edc.spi.system.ServiceExtension
└── src/test/java/org/gaiax/edc/policy/
    ├── TimeIntervalUsageFunctionTest.java
    └── RegionLocationFunctionTest.java

deployment/k3s/policies/
├── time-bound-access.jsonld
├── region-restricted.jsonld
└── researcher-credential-required.jsonld
```

**Java Implementation Templates:**

```java
// TimeIntervalUsageFunction.java
public class TimeIntervalUsageFunction implements AtomicConstraintRuleFunction<Permission> {
    @Override
    public boolean evaluate(Operator operator, Object rightValue, Permission rule, PolicyContext context) {
        // Parse ISO 8601 datetime from rightValue
        // Compare against current UTC timestamp
        // Return true if within allowed interval
    }
}
```

```java
// RegionLocationFunction.java
public class RegionLocationFunction implements AtomicConstraintRuleFunction<Permission> {
    @Override
    public boolean evaluate(Operator operator, Object rightValue, Permission rule, PolicyContext context) {
        // Extract region claim from Verifiable Presentation
        // Validate against allowed regions in rightValue
        // Return true if region matches
    }
}
```

---

### Phase 4: Federated Catalog and Data Dashboard (Weeks 11-13) - **NOT STARTED**

| Task | Status | Deliverable |
|------|--------|-------------|
| Federated Catalog crawler configuration | **TODO** | Updated FC values |
| Participant DID registration in crawler | **TODO** | Crawler config |
| Data Dashboard deployment | **TODO** | Dashboard Helm chart |
| Dashboard ↔ Management API wiring | **TODO** | Configuration |
| Simulated asset injection | **TODO** | curl/Postman scripts |
| Contract definition creation | **TODO** | API calls linking assets to policies |
| End-to-end asset discovery test | **TODO** | Test script |

**Dependencies:**
- Phase 3 must be complete (policies available to attach to assets)
- Federated Catalog already exists in MVD, needs configuration only

**Key Files to Create:**
```
deployment/k3s/catalog/
├── federated-catalog-values.yaml
└── crawler-targets.json

deployment/k3s/dashboard/
├── dashboard-deployment.yaml
├── dashboard-configmap.yaml
└── dashboard-ingress.yaml

scripts/seed-data/
├── create-assets.sh
├── create-policies.sh
├── create-contract-definitions.sh
└── assets/
    ├── carbon-emissions-dataset.json
    └── telemetry-analytics.json
```

---

### Phase 5: System Integration and Hardening (Weeks 14-16) - **NOT STARTED**

| Task | Status | Deliverable |
|------|--------|-------------|
| Integration test script | **TODO** | `integration-test.sh` |
| Contract negotiation flow test | **TODO** | Test scenario 1 |
| VP verification flow test | **TODO** | Test scenario 2 |
| Time-bound policy expiration test | **TODO** | Test scenario 3 |
| Geographic constraint test | **TODO** | Test scenario 4 |
| EDR token revocation test | **TODO** | Revocation verification |
| Documentation | **TODO** | Final technical docs |
| Deployment automation finalization | **TODO** | Production-ready scripts |

**Key Files to Create:**
```
tests/integration/
├── integration-test.sh
├── lib/
│   ├── dsp-client.sh
│   ├── dcp-client.sh
│   └── assertions.sh
├── scenarios/
│   ├── 01-time-bound-access.sh
│   ├── 02-credential-abac.sh
│   └── 03-geographic-constraint.sh
└── fixtures/
    ├── consumer-vp.json
    └── test-credentials/
```

---

## 5. Testing Scenario Requirements

### Test Scenario 1: Strict Time-Bound Access Constraint

**Blueprint Requirement:** Provider configures ODRL policy with `TimeIntervalUsage` pattern. Asset only accessible between specific start and end datetime.

| Component | MVD Status | Implementation Required |
|-----------|------------|------------------------|
| ODRL Policy Schema | Not provided | Create `time-bound-access.jsonld` |
| PolicyFunction | Not provided | Implement `TimeIntervalUsageFunction.java` |
| Test Harness | Not provided | Create test script |

**Test Flow:**
1. Provider registers asset with time-bound policy (e.g., valid 2026-04-01 to 2026-04-30)
2. Consumer attempts negotiation on 2026-03-15 (before window)
3. **Expected:** Negotiation rejected with policy violation
4. Consumer attempts negotiation on 2026-04-15 (within window)
5. **Expected:** Negotiation succeeds, EDR issued
6. Consumer attempts negotiation on 2026-05-01 (after window)
7. **Expected:** Negotiation rejected

---

### Test Scenario 2: Credential-Based ABAC

**Blueprint Requirement:** Provider requires `CertifiedEnvironmentalResearcher` credential to access restricted dataset.

| Component | MVD Status | Implementation Required |
|-----------|------------|------------------------|
| Credential Schema | Not provided | Create `CertifiedEnvironmentalResearcher` VC schema |
| Issuer Logic | Partial (generic) | Extend issuer to mint custom credential |
| ODRL Policy | Not provided | Create credential-required policy |
| PolicyFunction | Partial (`DataAccessLevelFunction`) | Adapt or create new function |

**Test Flow:**
1. Provider registers asset requiring `CertifiedEnvironmentalResearcher` VC
2. Consumer attempts negotiation WITHOUT the credential in Identity Hub
3. Provider issues VP challenge
4. Consumer submits VP missing required credential
5. **Expected:** Negotiation terminated
6. Consumer's Identity Hub is seeded with the required VC
7. Consumer re-initiates negotiation
8. **Expected:** Negotiation succeeds

---

### Test Scenario 3: Geographic Location Constraints

**Blueprint Requirement:** Provider restricts data processing to EU-located nodes only using `regionLocation` constraint.

| Component | MVD Status | Implementation Required |
|-----------|------------|------------------------|
| Geographic Claim in VP | Not provided | Add region claim to credential schema |
| ODRL Policy Schema | Not provided | Create `region-restricted.jsonld` |
| PolicyFunction | Not provided | Implement `RegionLocationFunction.java` |
| PostGIS Integration | Not provided (now added) | Optional spatial validation |

**Test Flow:**
1. Provider registers asset with EU-only policy
2. Consumer with non-EU DID/credentials attempts negotiation
3. **Expected:** Policy evaluation fails on geographic mismatch
4. Consumer with EU-located credentials attempts negotiation
5. **Expected:** Negotiation succeeds

---

## Appendix A: MVD Repository Structure Reference

```
MinimumViableDataspace/
├── extensions/
│   ├── dcp-impl/                    # DCP scope mapping, credential evaluation
│   ├── did-example-resolver/        # Custom DID resolution
│   ├── postgres-flyway/             # Database migrations
│   ├── refresh-catalog/             # Catalog refresh trigger
│   └── superuser-seed/              # Bootstrap credential seeding
├── launchers/
│   ├── catalog-server/              # Federated Catalog
│   ├── controlplane/                # EDC Control Plane
│   ├── dataplane/                   # EDC Data Plane
│   └── identity-hub/                # Identity Hub + STS
├── deployment/
│   ├── assets/                      # Terraform modules
│   ├── modules/                     # Reusable infra modules
│   └── k3s/                         # [NEW] Fontys K3s overlay
├── tests/
│   └── end2end/                     # Newman/Postman tests
└── gradle/                          # Build configuration
```

---

## Appendix B: Key API Endpoints Reference

### Control Plane Management API
- `POST /management/v3/assets` - Create asset
- `POST /management/v3/policydefinitions` - Create policy
- `POST /management/v3/contractdefinitions` - Create contract definition
- `POST /management/v3/contractnegotiations` - Initiate negotiation
- `GET /management/v3/contractnegotiations/{id}` - Get negotiation status
- `POST /management/v3/transferprocesses` - Initiate transfer

### DSP Protocol Endpoints
- `POST /api/dsp/catalog/request` - Catalog query
- `POST /api/dsp/negotiations/request` - Start negotiation
- `POST /api/dsp/negotiations/{id}/agreement` - Accept agreement

### Identity Hub DCP Endpoints
- `POST /api/identity/v1/participants/{id}/credentials` - Store credential
- `POST /api/identity/v1/participants/{id}/presentations` - Create VP
- `GET /.well-known/did.json` - DID document

---

## Appendix C: ODRL Policy Templates

### Time-Bound Access Policy
```json
{
  "@context": ["http://www.w3.org/ns/odrl.jsonld", {"gx": "https://w3id.org/gaia-x/"}],
  "@type": "Set",
  "permission": [{
    "action": "use",
    "constraint": [{
      "leftOperand": "gx:dateTime",
      "operator": "gteq",
      "rightOperand": {"@value": "2026-04-01T00:00:00Z", "@type": "xsd:dateTime"}
    }, {
      "leftOperand": "gx:dateTime",
      "operator": "lteq",
      "rightOperand": {"@value": "2026-04-30T23:59:59Z", "@type": "xsd:dateTime"}
    }]
  }]
}
```

### Region-Restricted Policy
```json
{
  "@context": ["http://www.w3.org/ns/odrl.jsonld", {"gx": "https://w3id.org/gaia-x/"}],
  "@type": "Set",
  "permission": [{
    "action": "use",
    "constraint": [{
      "leftOperand": "gx:regionLocation",
      "operator": "isPartOf",
      "rightOperand": "EU"
    }]
  }]
}
```

### Credential-Required Policy
```json
{
  "@context": ["http://www.w3.org/ns/odrl.jsonld", {"gx": "https://w3id.org/gaia-x/"}],
  "@type": "Set",
  "permission": [{
    "action": "use",
    "constraint": [{
      "leftOperand": "gx:credentialType",
      "operator": "eq",
      "rightOperand": "CertifiedEnvironmentalResearcher"
    }]
  }]
}
```

---

*Document generated for Fontys Dataspaces Project - March 2026*
