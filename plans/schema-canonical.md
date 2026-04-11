# MakerMargins — Canonical Data Schema

> Language-agnostic source of truth for the data model. Future Kotlin models (Android),
> TypeScript types (web), and Supabase Postgres schema all derive from this file.
> Update whenever SwiftData models change.
>
> **Last synced with Swift models:** Epic 7 Phase 2a (added remoteID, createdAt, updatedAt)

---

## Conventions

- **Primary key:** each platform uses its native auto-generated PK (SwiftData `persistentModelID`, Room auto-increment, Postgres `id serial`). NOT exposed cross-platform.
- **Sync ID:** `remoteID` (UUID, nullable) is the stable cross-platform identifier, populated by the future sync layer. Null until sync is implemented.
- **Timestamps:** `createdAt` (set once at creation), `updatedAt` (set on every write). Both non-null with default `now`.
- **Money:** all monetary values are **Decimal** (Swift), **BigDecimal** (Kotlin), **string** (JSON/API). Never `Double`/`float` for money.
- **Percentages/fractions:** stored as decimals where 0.10 = 10%. NOT stored as whole numbers.
- **Strings:** `summary` is the field name (avoids `description` collision with NSObject in Swift).

---

## Models

### Product
The central entity — a maker's SKU.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| title | String | required | |
| sku | String | "" | Free-text SKU / part number |
| summary | String | "" | User-facing description |
| image | Data? | nil | JPEG blob. Future: migrate to imageURL for sync. |
| shippingCost | Decimal | 0 | Per-unit, user's currency |
| materialBuffer | Decimal | 0 | Fraction (0.10 = 10%) |
| laborBuffer | Decimal | 0 | Fraction (0.05 = 5%) |
| remoteID | UUID? | nil | Sync field |
| createdAt | Date | now | Set once |
| updatedAt | Date | now | Set on every write |

**Relationships:**
- `category` → Category? (many-to-one, optional)
- `productWorkSteps` → [ProductWorkStep] (cascade delete)
- `productMaterials` → [ProductMaterial] (cascade delete)
- `productPricings` → [ProductPricing] (cascade delete)

---

### Category
Groups products into named collections.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| name | String | required | |
| remoteID | UUID? | nil | Sync field |
| createdAt | Date | now | |
| updatedAt | Date | now | |

**Relationships:**
- `products` → [Product] (nullify on delete — products survive)

---

### WorkStep (shared entity)
A labor step reusable across products via many-to-many join.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| title | String | required | |
| summary | String | "" | |
| image | Data? | nil | |
| recordedTime | TimeInterval | 0 | Seconds from stopwatch |
| batchUnitsCompleted | Decimal | 1 | Guards against division by zero |
| unitName | String | "unit" | e.g. "piece", "board" |
| defaultUnitsPerProduct | Decimal | 1 | Pre-fills join model |
| remoteID | UUID? | nil | |
| createdAt | Date | now | |
| updatedAt | Date | now | |

**Relationships:**
- `productWorkSteps` → [ProductWorkStep] (cascade delete)

---

### ProductWorkStep (join model)
Links a WorkStep to a Product with per-product overrides.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| sortOrder | Int | 0 | Display order within product |
| unitsRequiredPerProduct | Decimal | 1 | Per-product override |
| laborRate | Decimal | 0 | $/hour, per-product context |
| remoteID | UUID? | nil | |
| createdAt | Date | now | |
| updatedAt | Date | now | |

**Relationships:**
- `product` → Product? (many-to-one)
- `workStep` → WorkStep? (many-to-one)

---

### Material (shared entity)
A raw material input reusable across products via many-to-many join.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| title | String | required | |
| summary | String | "" | |
| image | Data? | nil | |
| link | String | "" | Supplier URL |
| bulkCost | Decimal | 0 | Total cost of bulk purchase |
| bulkQuantity | Decimal | 1 | Units in bulk purchase |
| unitName | String | "unit" | |
| defaultUnitsPerProduct | Decimal | 1 | Pre-fills join model |
| remoteID | UUID? | nil | |
| createdAt | Date | now | |
| updatedAt | Date | now | |

**Relationships:**
- `productMaterials` → [ProductMaterial] (cascade delete)

---

### ProductMaterial (join model)
Links a Material to a Product with per-product overrides.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| sortOrder | Int | 0 | Display order within product |
| unitsRequiredPerProduct | Decimal | 1 | Per-product override |
| remoteID | UUID? | nil | |
| createdAt | Date | now | |
| updatedAt | Date | now | |

**Relationships:**
- `product` → Product? (many-to-one)
- `material` → Material? (many-to-one)

---

### PlatformFeeProfile (singleton)
Universal user-configurable default pricing values. One record, created lazily.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| platformFee | Decimal | 0 | Fraction |
| paymentProcessingFee | Decimal | 0 | Fraction |
| marketingFee | Decimal | 0 | Fraction |
| percentSalesFromMarketing | Decimal | 0 | Fraction |
| profitMargin | Decimal | 0.30 | Fraction (30%) |
| remoteID | UUID? | nil | |
| createdAt | Date | now | |
| updatedAt | Date | now | |

---

### ProductPricing
Per-product per-platform pricing overrides. Up to 4 per product (one per PlatformType), created lazily.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| platformType | PlatformType | .general | Enum: general, etsy, shopify, amazon |
| platformFee | Decimal | 0 | |
| paymentProcessingFee | Decimal | 0 | |
| marketingFee | Decimal | 0 | |
| percentSalesFromMarketing | Decimal | 0 | |
| profitMargin | Decimal | 0.30 | |
| actualPrice | Decimal | 0 | What user actually charges |
| actualShippingCharge | Decimal | 0 | What customer pays for shipping |
| remoteID | UUID? | nil | |
| createdAt | Date | now | |
| updatedAt | Date | now | |

**Relationships:**
- `product` → Product? (many-to-one)

---

## Enums

### PlatformType
String-backed, codable.

| Case | Raw Value | Notes |
|------|-----------|-------|
| general | "General" | All fees user-editable |
| etsy | "Etsy" | Platform + processing + marketing fees locked |
| shopify | "Shopify" | Platform + processing locked, marketing editable |
| amazon | "Amazon" | Platform locked, processing bundled, marketing editable |

---

## Relationship Summary

```
Category ──nullify──< Product ──cascade──< ProductWorkStep >──cascade── WorkStep
                         │                                     
                         ├──cascade──< ProductMaterial >──cascade── Material
                         │
                         └──cascade──< ProductPricing

PlatformFeeProfile (singleton, no relationships)
```

---

## Future Sync Notes

- `remoteID` is populated by the sync layer when an entity is first uploaded. Null means "never synced."
- `updatedAt` drives conflict resolution: last-write-wins by default, with manual resolution for concurrent edits.
- `image: Data?` blobs will migrate to `imageURL: String?` + Supabase Storage when sync ships. Do not add new blob fields.
- `Decimal` must serialize as **string** over the wire (e.g. `"19.99"`), never as float/double.
