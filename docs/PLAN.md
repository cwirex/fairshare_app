# FairShare Development Plan

**Philosophy**: Build minimally, test thoroughly, iterate quickly.

## Current Status: Phase 2.2 Complete ✅

### Phase 1: Foundation ✅
- [x] Firebase Authentication with Google Sign-In
- [x] Offline-first database (Drift/SQLite)
- [x] Basic routing and navigation
- [x] Sign-out risk assessment
- [x] UI foundation (screens, theme, navigation)

### Phase 2.1 & 2.2: Core Functionality ✅
- [x] Expense creation and tracking
- [x] Personal groups (auto-created)
- [x] Shared groups (create & join)
- [x] Firebase sync with upload queue
- [x] Schema v5 refactoring (unified model)
- [x] Soft delete support
- [x] Foreign key constraints

## Phase 2: Minimal Working App 🎯

**Goal**: End-to-end functionality with simplest possible implementation. User can track expenses, see balances, and sync to cloud.

### 2.1 Expenses - Core Flow ✅ COMPLETE
**Priority**: Critical - This is the heart of the app

- [x] **Create expense and save to local DB**
  - Wire up CreateExpenseScreen form to database
  - Save with current user as payer
  - Default to "Personal" group (auto-created)
  - Equal split only (simplest case)

- [x] **Display expense list**
  - Replace empty state in ExpensesTab with ListView
  - Show: title, amount, date, payer
  - Sort by date (newest first)
  - Pull from local database

- [x] **Expense domain layer**
  - Create ExpenseEntity (pure data model with Freezed)
  - Create ExpenseRepository interface
  - Implement LocalExpenseRepository (Drift)
  - Add ExpenseFormatter helper for display logic

### 2.2 Groups - Basic Support ✅ COMPLETE
**Priority**: High - Needed for multi-user scenarios

- [x] **Auto-create "Personal" group**
  - Create on first sign-in + app startup
  - Single member (current user)
  - Use for ungrouped expenses

- [x] **Manual group creation**
  - GroupNotifier with createGroup method
  - Save to local database with 6-digit ID
  - Current user as sole member initially

- [x] **Display group list**
  - Replace empty state in GroupsTab
  - Show: name, tap for details (placeholder)
  - Stream updates from database

- [x] **Group domain layer**
  - Create GroupEntity (pure data model)
  - Create GroupMemberEntity
  - Create GroupRepository interface
  - Implement LocalGroupRepository
  - Add GroupInitializationService

**Key Learnings**:
- Fixed provider lifecycle with `@Riverpod(keepAlive: true)` for repositories
- Fixed auth provider to use synchronous `getCurrentUser()` method

### 2.3 Balances - Simple Calculation
**Priority**: High - Core value proposition

- [ ] **Calculate balances for a group**
  - Algorithm: Sum expenses per person
  - Show who paid what
  - Show who owes what
  - Simple list format: "Alice owes Bob $25"

- [ ] **Display in BalancesTab**
  - Replace empty state
  - Select group (dropdown)
  - Show calculated balances
  - "All settled up" when balanced

### 2.4 Firebase Sync - Basic Implementation ✅ COMPLETE
**Priority**: Medium - Can work offline for now

- [x] **Sync expenses to Firestore**
  - Push unsynced expenses on connectivity
  - Upload queue system (Option D from sync strategy)
  - Handle simple errors (retry later)
  - All expenses sync (including personal for backup)

- [x] **Sync groups to Firestore**
  - Push unsynced groups
  - Personal groups stay local (metadata only)
  - Basic conflict: last write wins

- [x] **Pull changes from Firestore**
  - Fetch on app start (if connected)
  - Simple merge: newer timestamp wins

- [ ] **Sync status indicator** (UI not yet implemented)
  - Show sync icon in app bar
  - Display unsynced count
  - Manual "Sync Now" button

**Key Implementation Details:**
- Upload queue table tracks pending operations
- Personal groups: `isPersonal: true` → metadata stays local, expenses sync
- Shared groups: `isPersonal: false` → everything syncs
- Repositories check `isPersonal` before enqueueing operations
- Firestore services handle upload/download with proper checks

## Phase 3: Multi-User & Collaboration

**Goal**: Share groups with others, see their expenses

- [ ] Group invitations (share code or link)
- [ ] Accept/decline invitations
- [ ] Add members to existing groups
- [ ] See expenses created by other members
- [ ] Real-time sync with conflict resolution

## Phase 4: Enhanced UX

**Goal**: Make the app delightful to use

- [ ] Expense categories with icons
- [ ] Custom split options (percentage, exact amounts)
- [ ] Edit/delete expenses
- [ ] Expense detail screen with history
- [ ] Search and filter expenses
- [ ] Date range selection
- [ ] Receipt photo attachment

## Phase 5: Settlement & Payments

**Goal**: Help users settle debts efficiently

- [ ] Optimize settlements (minimize transactions)
- [ ] Mark settlements as paid
- [ ] Settlement history
- [ ] Payment reminders
- [ ] Settlement suggestions

## Phase 6: Advanced Features

**Goal**: Power user features

- [ ] Multi-currency support with conversion
- [ ] Recurring expenses
- [ ] Expense templates
- [ ] Data export (CSV, PDF)
- [ ] Expense reports and analytics
- [ ] Push notifications
- [ ] Widgets for quick expense entry

## Technical Debt & Improvements

**Address as needed throughout development**

- [ ] Add unit tests for business logic
- [ ] Add widget tests for key screens
- [ ] Implement proper error boundaries
- [ ] Add analytics/crash reporting
- [ ] Performance optimization (lazy loading, pagination)
- [ ] Accessibility improvements (screen readers, font scaling)
- [ ] Localization (i18n)
- [ ] Onboarding flow for new users
- [ ] App icon and splash screen

## Non-Goals (For Now)

Things we're explicitly NOT doing yet:

- ❌ Complex split algorithms (by income, by consumption)
- ❌ Integration with payment platforms (Venmo, PayPal)
- ❌ AI-powered expense categorization
- ❌ Receipt OCR/scanning
- ❌ Web app or desktop versions
- ❌ Social features (comments, likes, activity feed)
- ❌ Gamification
- ❌ Premium/subscription tiers

## Success Metrics (Phase 2)

How we know Phase 2 is complete:

1. ✅ User can create an expense and see it in the list
2. ✅ User can create a group
3. ⏳ User can see balances for a group (schema ready, calculation pending)
4. ✅ Expenses sync to Firebase when online
5. ✅ App works completely offline
6. ✅ No crashes in basic flow
7. ✅ Can sign out and sign back in without data loss

**Status**: 6 of 7 complete. Only balance calculations remain for Phase 2 completion.

## Recent Accomplishments (2025-10-01)

### Major Schema Refactoring ✅
- **Removed denormalized data**: Deleted `User.groupIds`, made `group_members` single source of truth
- **Unified expense model**: Deleted `PersonalExpenseEntity`, use `ExpenseEntity` with `isPersonal` groups
- **Added soft deletes**: `deletedAt` on groups and expenses with restore capability
- **Foreign key constraints**: CASCADE deletes for data integrity
- **Balance tracking**: Created `GroupBalanceEntity` and table (calculation service pending)
- **Schema migration**: v4 → v5 with all queries updated

### Alignment Fixes ✅
- Fixed personal group initialization to set `isPersonal: true`
- Fixed UI group creation to explicitly set `isPersonal: false`
- Fixed all repository methods to check `isPersonal` before enqueueing
- Added soft delete filtering to all database queries
- Updated Firestore upload methods with `isPersonalGroup` parameter

### Documentation ✅
- Created comprehensive schema documentation
- Organized all docs into `docs/` folder
- Removed redundant/historical files

## Next Immediate Actions

**Start here** 👇

### Phase 2.3 - Balance Calculations
1. Implement balance calculation service
2. Update balances when expenses change
3. Display balances in BalancesTab
4. Add sync for balance data

### Optional Improvements
- Add sync status indicator UI
- Implement soft delete UI (undo functionality)
- Fix profile screen null-safety warnings
- Add unit tests for new schema

**One feature at a time. Make it work, then make it better.**

---

Last updated: 2025-10-01