# FairShare Development Plan

**Philosophy**: Build minimally, test thoroughly, iterate quickly.

## Current Status: MVP Phase 1 Complete ✅

- [x] Firebase Authentication with Google Sign-In
- [x] Offline-first database (Drift/SQLite)
- [x] Basic routing and navigation
- [x] Sign-out risk assessment
- [x] UI foundation (screens, theme, navigation)

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

### 2.4 Firebase Sync - Basic Implementation
**Priority**: Medium - Can work offline for now

- [ ] **Sync expenses to Firestore**
  - Push unsynced expenses on connectivity
  - Update isSynced flag
  - Handle simple errors (retry later)

- [ ] **Sync groups to Firestore**
  - Push unsynced groups
  - Basic conflict: last write wins

- [ ] **Pull changes from Firestore**
  - Fetch on app start (if connected)
  - Simple merge: newer timestamp wins

- [ ] **Sync status indicator**
  - Show sync icon in app bar
  - Display unsynced count
  - Manual "Sync Now" button

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
3. ✅ User can see balances for a group
4. ✅ Expenses sync to Firebase when online
5. ✅ App works completely offline
6. ✅ No crashes in basic flow
7. ✅ Can sign out and sign back in without data loss

## Next Immediate Actions

**Start here** 👇

1. Implement Expense entity and repository
2. Wire up CreateExpenseScreen to save expenses
3. Create expense list view
4. Test: Create expense → See in list → Sign out → Sign in → Still there

**One feature at a time. Make it work, then make it better.**

---

Last updated: 2025-09-30