# Real-Time Sync Architecture - Executive Summary

**Version:** 2.1
**Status:** ✅ Approved for Implementation
**Last Updated:** 2025-10-09

---

## 📋 TL;DR

We're upgrading from **periodic sync (30s polling)** to **real-time sync (< 1s latency)** while maintaining our offline-first architecture. The solution is cost-optimized, battery-efficient, and production-ready.

---

## 🎯 Key Goals

1. **Real-time collaboration** - Users see changes from other devices instantly
2. **Cost-optimized** - Minimal Firestore listeners (1-2 per user)
3. **Battery-efficient** - Foreground-only listeners
4. **Production-ready** - Atomic operations, server timestamps, conflict notifications
5. **Zero breaking changes** - Drop-in replacement for existing sync

---

## 🏗️ Architecture in 3 Sentences

1. **Upload Path:** User actions → Local DB (instant UI) → Upload Queue → Firestore (background)
2. **Download Path (Real-Time):** Firestore changes → Listener fires → Local DB updates → UI rebuilds automatically
3. **Hybrid Strategy:** Single global listener for all groups + dedicated listener for currently viewed group

---

## 💡 Key Innovations

### 1. Hybrid Listener Strategy (COST SAVINGS)

```
Instead of:   50 groups = 50 listeners = 💰💰💰
We use:       1 global + 1 active = 2 listeners = 💰
```

**How:**
- **Tier 1:** One listener watches ALL user's groups (metadata only)
- **Tier 2:** One listener watches ACTIVE group (full real-time)
- **Tier 3:** On-demand fetch when inactive group has new activity

**Result:** 95% cost reduction while maintaining premium UX where it matters

### 2. Server-Side Timestamps (RELIABILITY)

```
Before:  Client's DateTime.now() = ❌ Clock skew issues
After:   Firestore FieldValue.serverTimestamp() = ✅ Always correct
```

**Why:** Server is single source of truth for timestamps → reliable conflict resolution

### 3. Atomic Transactions (DATA INTEGRITY)

```
Before:  DB write → App crashes → Queue entry never created = ❌ Data loss
After:   transaction { DB write + Queue entry } = ✅ All or nothing
```

**Why:** No more orphaned data or inconsistent states

### 4. Foreground-Only Listeners (BATTERY SAVINGS)

```
Background listeners = 🔋🔋🔋 drain
Foreground-only + catch-up on resume = 🔋 minimal drain
```

**Why:** User doesn't notice 1s delay when opening app, but DOES notice battery drain

---

## 📊 Expected Metrics

| Metric | Target | Current (v1.0) | Improvement |
|--------|--------|----------------|-------------|
| Sync Latency (active view) | < 1s | 30s | **30x faster** |
| Active Listeners per User | 1-2 | 0 | Minimal overhead |
| Firestore Reads per Day | < 500 | ~1000 | **50% reduction** |
| Battery Drain | < 5% | 0% | Acceptable increase |
| Conflict Resolution Accuracy | 99.9% | N/A | LWW with server timestamps |

---

## 🔄 Data Flow (Simplified)

### Write Flow
```
User creates expense
    ↓ (0ms)
Local DB ────→ UI updates instantly ✨
    ↓ (100ms)
Upload Queue
    ↓ (500ms)
Firestore
    ↓ (< 1s)
Other devices get real-time update 🔥
```

### Read Flow
```
Device B changes expense
    ↓
Firestore document updated
    ↓ (< 1s)
Device A's listener fires ⚡
    ↓
Local DB updated
    ↓
UI rebuilds automatically
    ↓
User sees change (no manual refresh needed)
```

---

## 🛠️ Implementation Phases

| Phase | Description | Duration | Status |
|-------|-------------|----------|--------|
| 0 | Pre-implementation (feature flags, monitoring) | 2 days | ⏳ Pending |
| 1 | Database updates (upsert methods, soft delete) | 3 days | ⏳ Pending |
| 2 | Firestore real-time streams | 4 days | ⏳ Pending |
| 3 | RealtimeSyncService implementation | 3 days | ⏳ Pending |
| 4 | Update SyncService integration | 2 days | ⏳ Pending |
| 5 | Simplify repositories | 2 days | ⏳ Pending |
| 6 | Update providers | 1 day | ⏳ Pending |
| 7 | Replace print with logging | 2 days | ⏳ Pending |
| 8 | End-to-end testing | 5 days | ⏳ Pending |
| 9 | Documentation | 2 days | ⏳ Pending |
| **Total** | **Complete implementation** | **~4 weeks** | **Ready to start** |

---

## 🎨 Clean Architecture Compliance

### Before (v1.0 - Had Issues)
```
❌ Repositories calling Firestore directly
❌ Repositories checking connectivity
❌ Sync logic scattered across layers
❌ No atomic operations
❌ Client-side timestamps
```

### After (v2.1 - Clean)
```
✅ Repositories = Local DB + Queue ONLY
✅ SyncService = Orchestration ONLY
✅ RealtimeSyncService = Listeners ONLY
✅ Clear separation of concerns
✅ Atomic transactions everywhere
✅ Server-side timestamps
```

---

## 🚨 Critical Design Decisions

### ✅ APPROVED

1. **Hybrid Listener Strategy** - Cost & battery optimized
2. **Server Timestamps** - Reliable conflict resolution
3. **Atomic Transactions** - Data integrity
4. **Foreground-Only Listeners** - Battery savings
5. **Conflict Notifications** - Better UX
6. **Soft Delete Pattern** - Safer deletes
7. **Feature Flag Rollout** - Gradual deployment

### ❌ REJECTED

1. **Listener per Group** - Too expensive
2. **Client Timestamps** - Clock skew issues
3. **Background Listeners** - Battery drain
4. **Big-Bang Deployment** - Too risky
5. **Complex Metadata** - Unnecessary complexity

---

## 📝 Schema Changes Required

### New Field: `lastActivityAt` in Group Documents

```dart
class GroupEntity {
  final String id;
  final String displayName;
  final DateTime lastActivityAt; // ← NEW FIELD
  // ... other fields
}
```

**Purpose:** Triggers smart refresh for inactive groups when activity occurs

**Updated By:**
- Expense created/updated/deleted
- Member added/removed
- Group settings changed

**Cost:** One extra write per group activity (negligible)

---

## 🧪 Testing Checklist

### Unit Tests (80% coverage target)
- [ ] Repository operations are atomic
- [ ] Queue operations retry on failure
- [ ] Server timestamps handled correctly
- [ ] Conflict detection works
- [ ] Soft delete + hard delete flow

### Integration Tests (60% coverage target)
- [ ] Local DB → Queue → Firestore flow
- [ ] Listener → Local DB → UI flow
- [ ] Transaction rollback on failure
- [ ] Listener reconnection after network loss

### E2E Tests (5 critical scenarios)
- [ ] Offline expense creation → online sync
- [ ] Real-time update across two devices
- [ ] Conflict resolution (concurrent edits)
- [ ] Queue retry on network failure
- [ ] Listener reconnection after app resume

---

## 🚀 Deployment Strategy

### Week 1: Internal Testing (10% of users)
- Feature flag: `realtime_sync_enabled = true` for team only
- Monitor metrics closely
- Fix any critical bugs

### Week 2: Beta Users (25% of users)
- Expand feature flag to beta testers
- Gather user feedback
- Validate cost/battery metrics

### Week 3: General Rollout (100% of users)
- Full rollout to all users
- Keep old sync code as fallback for 1 month
- Monitor for issues

### Rollback Plan
- If critical issues: Toggle feature flag off
- Old sync code still present for 1 month
- No data loss (queue preserves operations)

---

## 📞 Team Contacts

| Role | Responsibility | Contact |
|------|---------------|---------|
| **Tech Lead** | Architecture approval, code review | [Name] |
| **Backend Dev** | Firestore services, sync logic | [Name] |
| **Mobile Dev** | Repositories, UI integration | [Name] |
| **QA Lead** | Testing strategy, E2E tests | [Name] |
| **DevOps** | Monitoring, feature flags | [Name] |
| **Product Owner** | Requirements, rollout approval | [Name] |

---

## 📚 Related Documents

1. **[REALTIME_SYNC_ARCHITECTURE.md](./REALTIME_SYNC_ARCHITECTURE.md)** - Complete technical specification (2000+ lines)
2. **[SYNC_ARCHITECTURE.md](./SYNC_ARCHITECTURE.md)** - Original v1.0 design (for reference)
3. **[DATA_SCHEMA_COMPLETE.md](./DATA_SCHEMA_COMPLETE.md)** - Database schema documentation

---

## 🎯 Success Criteria

### Must Have (Launch Blockers)
- ✅ All unit tests passing (80% coverage)
- ✅ All E2E scenarios passing
- ✅ No data loss in stress tests
- ✅ Sync latency < 2s in worst case
- ✅ Zero crashes in sync operations

### Nice to Have (Post-Launch)
- ⭐ Sync latency < 1s average
- ⭐ Firestore cost < $50/month for 1000 users
- ⭐ Battery drain < 3% increase
- ⭐ User satisfaction with conflict notifications

---

## ❓ FAQ

### Q: Will this break existing functionality?
**A:** No. This is a drop-in replacement. Old code remains as fallback.

### Q: What if Firestore has an outage?
**A:** App continues working offline. Queue stores operations. Syncs when Firestore is back.

### Q: What if user has 100+ groups?
**A:** No problem. Hybrid strategy means only 2 listeners active regardless of group count.

### Q: How do we handle very large expenses lists?
**A:** Local DB query is fast (indexed). Firestore listener sends only deltas. Pagination can be added later if needed.

### Q: What about users on slow networks?
**A:** UI is always instant (offline-first). Sync happens in background. User never waits.

### Q: Can users opt out of real-time sync?
**A:** Not initially. But we can add a "Battery Saver Mode" that disables listeners and uses periodic sync instead.

---

## 📈 Next Steps

1. ✅ Architecture approved
2. ⏳ Assign team members to phases
3. ⏳ Set up feature flag system
4. ⏳ Create Firestore indexes
5. ⏳ Start Phase 1 implementation

**Estimated Start Date:** [To be assigned]
**Estimated Completion:** 4 weeks from start

---

**Document Version:** 2.1
**Last Updated:** 2025-10-09
**Status:** Ready for Implementation
