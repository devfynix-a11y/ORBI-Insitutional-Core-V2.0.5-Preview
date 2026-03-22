# ORBI Gateway Message Templates

This document outlines all the message templates used by the ORBI backend system, along with their required variables. These templates must be configured in your ORBI Gateway to ensure SMS, Push, and Email notifications are formatted correctly.

## Architecture

1. **Template Types (`/backend/templates/template_types.ts`)**: Defines the exact structure and required variables for every template. This provides strict TypeScript safety when calling `orbiGatewayService.sendTemplate`.
2. **Seed File (`/backend/templates/orbi_gateway_templates.json`)**: A JSON array containing the actual text/HTML for all templates across all channels and languages. This file should be imported into the ORBI Gateway database.
3. **Gateway Service (`/backend/infrastructure/orbiGatewayService.ts`)**: The HTTP client that sends the `templateName` and `data` payload to the external Gateway.

## How to Sync to Gateway

To update the templates on the ORBI Gateway, copy the contents of `/docs/orbi_gateway_templates.json` and import it into the Gateway's database. The Gateway will automatically match the `name`, `channel`, and `language` fields when a request is received.

> **⚠️ Important Naming Convention Note:**
> There is a strict distinction between how templates are *stored* versus how they are *requested*:
> * **Template Creation/Import (JSON):** When importing templates into the Gateway database, the identifier field must be called `"name"` (e.g., `"name": "OTP_Message"`).
> * **API Requests (POST):** When the backend sends a request to the Gateway's `/api/send-template` endpoint, the identifier field in the JSON payload must be called `"templateName"` (e.g., `"templateName": "OTP_Message"`).

## Available Templates

Templates are provided in both Swahili (`sw`) and English (`en`).

---

### 1. OTP Verification
**Template Name:** `OTP_Message`
**Variables:** `otp`, `androidHash` (optional), `name` (optional), `refId`, `deviceName`

**Swahili (`sw`)**
```text
Ref: {{refId}}. ORBI Usalama:
Namba yako ya siri ya muda (OTP) ya Orbi ni: {{otp}}. Itatumika kwa dakika 5 pekee kwenye kifaa chako cha {{deviceName}}.
```

**English (`en`)**
```text
Ref: {{refId}}. ORBI Security Verification:
Your Orbi verification code is: {{otp}}. It expires in 5 minutes on your {{deviceName}}.
```

---

### 2. Security Alerts
**Template Name:** `Security_Alert_Message`
**Variables:** `subject`, `body`, `refId`, `deviceName`

**Swahili (`sw`)**
```text
Ref: {{refId}}. ORBI Financial Technologies:
Taarifa ya Usalama: {{subject}}. Maelezo: {{body}} kwenye kifaa cha {{deviceName}}.
Kutoka Mifumo ya Usalama ya ORBI. Tafadhali wasiliana nasi haraka kwa tatizo lolote. Simu: +255764258114
```

**English (`en`)**
```text
Ref: {{refId}}. ORBI Financial Technologies:
Security Alert: {{subject}}. Details: {{body}} on device {{deviceName}}.
From Orbi Security System, contact support immediately incase of any issue. Call: +255764258114
```

---

### 3. Salary Received
**Template Name:** `Salary_Received`
**Variables:** `amount`, `currency`, `employeeName`, `month`, `timestamp`, `refId`, `footer`

**Swahili (`sw`)**
```text
{{refId}}. Ndugu {{employeeName}}, mshahara wako wa mwezi {{month}} kiasi cha {{currency}} {{amount}} umeingia kwenye akaunti yako ya ORBI saa {{timestamp}}. {{footer}}
```

**English (`en`)**
```text
{{refId}}. Dear {{employeeName}}, your salary for {{month}} of {{currency}} {{amount}} has been credited to your ORBI account at {{timestamp}}. {{footer}}
```

---

### 4. Transfer Received
**Template Name:** `Transfer_Received`
**Variables:** `amount`, `currency`, `senderName`, `recipientName`, `timestamp`, `refId`, `footer`

**Swahili (`sw`)**
```text
{{refId}}. Ndugu {{recipientName}}, imethibitishwa umepokea {{currency}} {{amount}}/= kwenye akaunti yako ya ORBI kutoka kwa {{senderName}} saa {{timestamp}}. {{footer}}
```

**English (`en`)**
```text
{{refId}}. Dear {{recipientName}}, confirmed you have received {{currency}} {{amount}}/= on your ORBI account from {{senderName}} at {{timestamp}}. {{footer}}
```

---

### 5. Transfer Sent
**Template Name:** `Transfer_Sent`
**Variables:** `amount`, `currency`, `senderName`, `recipientName`, `timestamp`, `refId`, `footer`

**Swahili (`sw`)**
```text
{{refId}}. Ndugu {{senderName}}, imethibitishwa umetuma {{currency}} {{amount}}/= kutoka kwenye akaunti yako ya ORBI kwenda kwa {{recipientName}} saa {{timestamp}}. {{footer}}
```

**English (`en`)**
```text
{{refId}}. Dear {{senderName}}, confirmed you have sent {{currency}} {{amount}}/= from your ORBI account to {{recipientName}} at {{timestamp}}. {{footer}}
```

---

### 6. Escrow Created (Pending Payment)
**Template Name:** `Escrow_Created`
**Variables:** `amount`, `currency`

**Swahili (`sw`)**
```text
ORBI Financial Technologies:
Una malipo yanayosubiri ya {{currency}} {{amount}} kutoka kwa mteja. Fedha zimewekwa salama kwenye Orbi PaySafe na zitatolewa baada ya uthibitisho wa kupokea mzigo.
```

**English (`en`)**
```text
ORBI Financial Technologies:
You have a pending payment of {{currency}} {{amount}}/= from a customer. Funds are locked in Orbi PaySafe and will be released upon delivery confirmation.
```

---

### 7. Escrow Released
**Template Name:** `Escrow_Released`
**Variables:** `amount`, `currency`

**Swahili (`sw`)**
```text
ORBI Financial Technologies:
Malipo ya {{currency}} {{amount}} yametolewa kwenye akaunti yako ya uendeshaji.
```

**English (`en`)**
```text
ORBI Financial Technologies:
PaySafe funds of {{currency}} {{amount}} have been released to your operating account.
```

---

### 8. Treasury Withdrawal Request (For Admins)
**Template Name:** `Treasury_Withdrawal_Request`
**Variables:** `amount`, `currency`, `reason`

**Swahili (`sw`)**
```text
ORBI Financial Technologies:
Ombi jipya la kutoa fedha za hazina la {{currency}} {{amount}} linahitaji idhini yako. Sababu: {{reason}}
```

**English (`en`)**
```text
ORBI Financial Technologies:
A new treasury withdrawal request for {{currency}} {{amount}} requires your approval. Reason: {{reason}}
```

---

### 9. Low Balance Alert (Push)
**Template Name:** `LOW_BALANCE`
**Variables:** `name`, `threshold`

**Swahili (`sw`)**
```text
Habari {{name}}, salio la akaunti yako ni chini ya {{threshold}}. Tafadhali ongeza salio kuendelea kufurahia huduma zetu.
```

**English (`en`)**
```text
Hi {{name}}, your account balance is below {{threshold}}. Please top up to continue enjoying our services.
```

---

### 10. Generic Transactional Message
**Template Name:** `Transactional_Message`
**Variables:** `body`, `refId`

**Swahili (`sw`)**
```text
Ref: {{refId}}. ORBI Financial Technologies:
{{body}}
```

**English (`en`)**
```text
Ref: {{refId}}. ORBI Financial Technologies:
{{body}}
```

---

### 11. New Device Alert
**Template Name:** `New_Device_Alert`
**Variables:** `deviceName`, `location`, `timestamp`, `refId`

**Swahili (`sw`)**
```text
Ref: {{refId}}. ORBI Usalama:
Kifaa kipya ({{deviceName}}) kimeingia kwenye akaunti yako kutoka {{location}} saa {{timestamp}}. Kama siyo wewe, badilisha namba yako ya siri haraka.
```

**English (`en`)**
```text
Ref: {{refId}}. ORBI Security Alert:
A new device ({{deviceName}}) has logged into your account from {{location}} at {{timestamp}}. If this wasn't you, change your PIN immediately.
```

---

### 11. Welcome Message
**Template Name:** `Welcome_Message`
**Variables:** `name`

**Swahili (`sw`)**
```text
ORBI Financial Technologies:
Habari {{name}}, karibu Orbi! Akaunti yako imefunguliwa na kukamilika. Tunafurahi kukusaidia kusimamia mali zako kwa usalama.
```

**English (`en`)**
```text
ORBI Financial Technologies:
Hello {{name}}, welcome to Orbi! Your account is now active. We are excited to help you manage your assets securely.
```

---

### 12. Promotional Message
**Template Name:** `Promo_Message`
**Variables:** `body`

**Swahili (`sw`)**
```text
ORBI Financial Technologies:
Ofa Maalum: {{body}}
```

**English (`en`)**
```text
ORBI Financial Technologies:
Exclusive Offer: {{body}}
```
