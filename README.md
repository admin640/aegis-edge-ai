# 🛡️ Aegis — Air-Gapped Edge AI for Regulated Industries

> **On-device Gemma 4 inference for healthcare & legal professionals where cloud AI is illegal.**

[![Gemma 4](https://img.shields.io/badge/Gemma_4-E4B-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://deepmind.google/models/gemma/gemma-4/)
[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Storage-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Privacy](https://img.shields.io/badge/Privacy-Zero_Cloud-00C853?style=for-the-badge&logo=shield&logoColor=white)]()

---

## 🎯 The Problem

**Cloud AI is illegal for 40% of professional conversations.**

| Regulation | Scope | Penalty |
|---|---|---|
| **HIPAA** (Healthcare) | All patient health information | Up to $50K per violation |
| **42 CFR Part 2** | Substance abuse records | Criminal penalties |
| **Attorney-Client Privilege** | All legal consultations | Malpractice, disbarment |

Therapists, physicians, and attorneys **cannot** send session transcripts to cloud APIs — not to OpenAI, not to Google Cloud, not to anyone. Yet they spend **2+ hours daily** on documentation.

**Aegis solves this with 100% on-device AI.** The model downloads once. After that, it runs forever offline. Raw data never leaves the device.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                    AEGIS EDGE LAYER                  │
│                                                     │
│   ┌──────────────┐    ┌──────────────────────────┐ │
│   │  Microphone   │    │     Gemma 4 E4B           │ │
│   │  (16kHz M4A)  │───▶│     On-Device LLM         │ │
│   └──────────────┘    │     3.4 GB / LiteRT-LM     │ │
│                        └─────────┬────────────────┘ │
│                                  │                   │
│   ┌──────────────────────────────▼──────────────┐   │
│   │           REDACTION ENGINE                   │   │
│   │   SSN │ Phone │ Email │ DOB │ MRN │ DEA     │   │
│   └──────────────────────────────┬──────────────┘   │
│                                  │                   │
│              ┌───────────┬───────┴──────┐           │
│              ▼           ▼              ▼           │
│        ┌──────────┐ ┌──────────┐ ┌───────────┐     │
│        │  Local    │ │  Display │ │  PII Audit│     │
│        │  Storage  │ │  to User │ │  Badge    │     │
│        └──────────┘ └──────────┘ └───────────┘     │
│                                                     │
├─────────────────── PRIVACY WALL ────────────────────┤
│                                                     │
│   ┌──────────────────────────────────────────────┐ │
│   │          CLOUD SYNC (Redacted Only)           │ │
│   │   Firestore ← Only PII-free text syncs       │ │
│   │   Safety Gate: Sync disabled if PII detected  │ │
│   └──────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

### Key Design Decision: Privacy Wall

The **Privacy Wall** is an architectural boundary, not a feature flag. Raw patient/client data physically cannot reach cloud services because:

1. **Inference is local** — Gemma 4 runs via LiteRT-LM, no network call needed
2. **Redaction before display** — `RedactionService` strips PII before any UI render
3. **Double-redaction on sync** — `FirestoreService` re-redacts before cloud write
4. **Safety gate** — Cloud sync button is disabled when PII audit detects sensitive data

---

## 🧠 Gemma 4 Integration

### Model: Gemma 4 E4B (Effective 4 Billion parameters)

| Spec | Value |
|---|---|
| **Release** | April 2, 2026 |
| **Model Size** | 3.65 GB (.litertlm) |
| **Weights** | 2.24 GB (mixed 4-bit/8-bit quantization) |
| **Embeddings** | 0.67 GB (memory-mapped) |
| **Context** | Up to 32K tokens |
| **Runtime** | LiteRT-LM (Google's edge inference engine) |
| **Modalities** | Text + Vision + Audio |

### Why Gemma 4 on-device?

1. **Legal compliance** — Satisfies HIPAA, 42 CFR Part 2, attorney-client privilege
2. **Zero latency** — No network round-trip, instant inference
3. **Zero cost** — No per-token API billing after model download
4. **Offline-ready** — Works in hospitals, courtrooms, rural clinics with no connectivity
5. **Patient trust** — "Your data never left this device" is a powerful statement

### Model Delivery Pipeline

```
HuggingFace (litert-community/gemma-4-E4B-it-litert-lm)
         │
         ▼  One-time admin download
  Firebase Storage (models/gemma-4-E4B-it.litertlm)
         │
         ▼  Authenticated download to device
  Local device storage (~/.aegis/models/)
         │
         ▼  LiteRT-LM runtime loads model
  On-device inference (zero network)
```

### flutter_gemma Integration (v0.12.8)

```dart
// Initialize runtime at app startup
GemmaService.initializeRuntime();

// Install model from Firebase Storage (one-time)
await gemma.installModel(source: ModelSource.firebaseStorage);

// Generate a clinical note (single-turn)
final note = await gemma.generateResponse(
  'Convert this transcript to SOAP format: ...',
);

// Multi-turn legal analysis (chat session)
final chat = gemma.createChat(systemInstruction: legalPrompt);
final response = await chat.sendMessage('Analyze this evidence: ...');
```

---

## 🏥 Healthcare Workspace

**Clinical Documentation AI** — Converts session transcripts to structured clinical notes.

### Features
- **Audio Recording** — 16kHz mono M4A capture with pause/resume
- **Three Note Formats**:
  - **SOAP** (Subjective, Objective, Assessment, Plan)
  - **DAP** (Data, Assessment, Plan)
  - **BPS** (Biopsychosocial)
- **PII Redaction** — Real-time highlighting of SSN, phone, email, DOB, MRN, DEA numbers
- **Audit Badge** — Visual indicator of PII presence (✓ Clean / ⚠ PII Detected)
- **Safety Gate** — Cloud sync automatically disabled when PII detected
- **42 CFR Part 2 Compliant** — Substance abuse records never leave device

### Prompt Engineering

Each note format uses specialized system prompts that enforce:
- Proper medical terminology and section headers
- Third-person clinical language
- No personally identifiable information in output
- Evidence-based assessment language

---

## ⚖️ Legal Workspace

**Evidence Analysis AI** — Multi-turn chat interface for legal document analysis.

### Features
- **Three Analysis Modes**:
  - 🔍 **Evidence Analysis** — Examine transcripts for inconsistencies, alibi gaps, witness reliability
  - 📋 **Transcript Summary** — Condense depositions, hearings, and testimony
  - 📑 **Discovery Review** — Flag privileged material, identify production obligations
- **Severity Markers** — Color-coded findings (🔴 Critical / 🟡 Notable / 🟢 Standard)
- **Multi-Turn Chat** — Maintains context across an entire evidence review session
- **Export** — Copy full analysis report to clipboard

### Attorney-Client Privilege Protection

The Legal workspace enforces privilege protection by:
1. Never transmitting raw legal documents to any cloud service
2. Running all analysis locally via Gemma 4
3. Prefixing exports with "PRIVILEGED AND CONFIDENTIAL" headers
4. Maintaining full audit trail of what was analyzed

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry + Firebase init + routing
├── firebase_options.dart              # FlutterFire auto-generated config
│
├── core/
│   ├── auth/
│   │   └── auth_service.dart          # Firebase Auth (Google Workspace)
│   ├── constants/
│   │   ├── app_constants.dart         # Model config, session limits
│   │   └── workspace_config.dart      # AegisWorkspace enum
│   ├── engine/
│   │   ├── gemma_service.dart         # ⭐ Gemma 4 E4B inference engine
│   │   ├── audio_service.dart         # Microphone capture (M4A)
│   │   └── redaction_service.dart     # PII detection & sanitization
│   ├── storage/
│   │   ├── firestore_service.dart     # Double-redacted cloud sync
│   │   └── local_storage_service.dart # On-device encrypted storage
│   └── theme/
│       └── aegis_theme.dart           # Premium dark-mode design system
│
├── models/
│   ├── session.dart                   # Session model (privacy-safe serialization)
│   └── workspace.dart                 # Workspace definitions
│
└── workspaces/
    ├── workspace_selector.dart        # Glassmorphic workspace chooser
    ├── healthcare/
    │   ├── healthcare_home.dart       # Recording + note generation UI
    │   ├── clinical_note_screen.dart  # Note viewer with PII highlighting
    │   └── prompts/
    │       └── clinical_prompts.dart  # SOAP/DAP/BPS system prompts
    └── legal/
        ├── legal_home.dart            # Multi-turn evidence chat UI
        └── prompts/
            └── legal_prompts.dart     # Miranda/evidence/discovery prompts
```

**19 Dart files • 3,916 lines of code**

---

## 🚀 Getting Started

### Prerequisites
- Flutter 3.41+ with macOS/iOS platform support
- Firebase project with Storage enabled
- Gemma 4 E4B model file (3.65 GB)

### Setup

```bash
# 1. Clone and install dependencies
git clone https://github.com/YOUR_USERNAME/aegis.git
cd aegis
flutter pub get

# 2. Configure Firebase
flutterfire configure

# 3. Download Gemma 4 model and upload to Firebase Storage
curl -L -o gemma-4-E4B-it.litertlm \
  "https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm"

gcloud storage cp gemma-4-E4B-it.litertlm \
  gs://YOUR_PROJECT.firebasestorage.app/models/

# 4. Deploy Firebase rules
firebase deploy --only firestore,storage

# 5. Run on macOS
flutter run -d macos
```

---

## 🔐 Security Model

| Layer | Mechanism | Purpose |
|---|---|---|
| **Inference** | LiteRT-LM (local) | Zero cloud transmission of raw data |
| **Redaction** | Regex patterns (SSN, phone, email, DOB, MRN, DEA) | Strip PII before display |
| **Audit** | PII audit badge | Visual compliance indicator |
| **Safety Gate** | Sync disabled on PII detection | Prevent accidental cloud leak |
| **Double Redaction** | FirestoreService re-redacts before write | Defense-in-depth |
| **Auth** | Firebase Auth (Google Workspace) | Organization-level access control |
| **Firestore Rules** | Org-scoped isolation | Multi-tenant data separation |
| **Storage Rules** | Public models, org-scoped files | Read-only model access for all users |

---

## 🏆 Why This Wins

1. **Illegal to Compete** — ChatGPT, Claude, and Gemini Cloud literally cannot serve this market due to HIPAA/privilege laws
2. **Day-1 Revenue** — Therapists pay $99/mo for documentation tools; lawyers pay $299/mo
3. **Zero Marginal Cost** — After model download, inference is free forever
4. **Gemma 4 Native** — First production app targeting Gemma 4 E4B (released April 2, 2026)
5. **Cross-Platform** — Same codebase runs on macOS, iOS, iPad — Flutter advantage

---

## 📊 Market Size

| Segment | Practitioners (US) | Avg. Documentation Time | Willingness to Pay |
|---|---|---|---|
| Therapists/Counselors | 198,000 | 2.5 hrs/day | $79-149/mo |
| Attorneys | 1,300,000 | 1.5 hrs/day | $199-499/mo |
| Physicians | 1,100,000 | 2 hrs/day | $99-299/mo |

**TAM: $3.2B/year** (US only, documentation tools for regulated professionals)

---

## 🛠️ Tech Stack

| Component | Technology |
|---|---|
| **Framework** | Flutter 3.41 (macOS + iOS) |
| **On-Device AI** | Gemma 4 E4B via flutter_gemma 0.12.8 |
| **AI Runtime** | LiteRT-LM (Google's edge inference) |
| **Backend** | Firebase (Auth, Firestore, Storage) |
| **Audio** | record 6.2.0 (M4A, 16kHz mono) |
| **State** | Provider (ChangeNotifier pattern) |
| **Theme** | Custom dark-mode design system |

---

## 📄 License

MIT License — See [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>Built for the Gemma 4 Good Hackathon</strong><br>
  <em>Because regulatory compliance should enable AI, not prevent it.</em>
</p>
